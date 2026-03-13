# frozen_string_literal: true

require 'date'

require 'dify/dataset_client'
require 'dify/article_collector'
require 'dify/article_summarizer'
require 'dify/chunking_config'

module Dify
  class KnowledgeExporter
    attr_reader :api_base, :dataset_id, :dataset_token, :base_url,
                :dataset_client, :article_collector, :env

    def initialize(
      api_base: ENV.fetch('DIFY_API_BASE', 'https://api.dify.ai'),
      dataset_id: ENV['DATASET_ID'],
      dataset_token: ENV['DATASET_API_KEY'],
      base_url: (ENV['BASE_URL'] || '').sub(%r{/\z}, ''),
      summarize: nil,
      env: ENV
    )
      @api_base = api_base
      @dataset_id = dataset_id
      @dataset_token = dataset_token
      @base_url = base_url
      @env = env
      @summarize = summarize.nil? ? (env['SUMMARIZE'].to_s != '0') : summarize
      @summarizer = ArticleSummarizer.new if @summarize

      @dataset_client = DatasetClient.new(
        api_base: api_base,
        dataset_id: dataset_id,
        dataset_token: dataset_token,
        env: env
      )
      @article_collector = ArticleCollector.new(base_url: base_url)
    end

    def credentials_present?
      dataset_client.credentials_present?
    end

    def refresh_yearly!(sleep_secs: nil, retries: nil, chunk_size: nil, chunk_delimiter: nil)
      dataset_client.ensure_credentials!

      params = resolve_params(sleep_secs: sleep_secs, retries: retries, chunk_size: chunk_size, chunk_delimiter: chunk_delimiter)
      groups = article_collector.collect_by_year(label: 'refresh_yearly')
      name2id = build_name_to_docid_map

      batch = []
      groups.sort.each do |year, items|
        items = maybe_summarize(items, label: "refresh_yearly/#{year}")
        text = article_collector.compose_year_text(items, delimiter: params[:chunking].delimiter)
        doc_id = create_or_update_document!(year, text, name2id, params)

        batch << build_metadata_entry(doc_id, year, items.size)

        flush_batch_if_full!(batch, params)
        sleep params[:sleep_secs]
      rescue Interrupt
        warn "[refresh_yearly] interrupted by user"; raise
      rescue StandardError => e
        warn "[refresh_yearly] skip #{year}: #{e.class} #{e.message}"
      end

      flush_remaining_metadata!(batch, params)

      puts "[refresh_yearly] done."
    end

    def repair_year_metadata!(batch_size: nil)
      dataset_client.ensure_credentials!

      batch_size = (batch_size || 20).to_i
      name2id = build_name_to_docid_map
      counts = article_collector.count_by_year

      missing = counts.keys.reject { |y| name2id.key?(y) }.sort
      warn "[repair] WARNING: not found for years: #{missing.join(', ')}" unless missing.empty?

      payloads = counts.sort.filter_map do |(year, cnt)|
        doc_id = name2id[year]
        next unless doc_id

        build_metadata_entry(doc_id, year, cnt)
      end

      if payloads.empty?
        puts "[repair] nothing to update"
        return
      end

      payloads.each_slice(batch_size) do |slice|
        res = dataset_client.update_documents_metadata!(slice)
        puts "[repair] updated #{slice.size} docs (status=#{res.code})"
        sleep 1.0
      rescue StandardError => e
        warn "[repair] slice failed: #{e.class} #{e.message}"
      end

      puts "[repair] done."
    end

    def touch_all!(batch_size: nil)
      dataset_client.ensure_credentials!

      batch_size = (batch_size || 20).to_i
      name2id = build_name_to_docid_map
      counts = article_collector.count_by_year

      payloads = name2id.sort.filter_map do |(year, doc_id)|
        cnt = counts[year] || 0
        build_metadata_entry(doc_id, year, cnt)
      end

      if payloads.empty?
        puts "[touch] no documents found"
        return
      end

      payloads.each_slice(batch_size) do |slice|
        res = dataset_client.update_documents_metadata!(slice)
        puts "[touch] touched #{slice.size} docs (status=#{res.code})"
        sleep 1.0
      rescue StandardError => e
        warn "[touch] slice failed: #{e.class} #{e.message}"
      end

      puts "[touch] done. #{payloads.size} documents touched."
    end

    def update_year!(year:, sleep_secs: nil, retries: nil, chunk_size: nil, chunk_delimiter: nil)
      dataset_client.ensure_credentials!

      year = (year || Time.now.year.to_s).to_s
      params = resolve_params(sleep_secs: sleep_secs, retries: retries, chunk_size: chunk_size, chunk_delimiter: chunk_delimiter)

      name2id = build_name_to_docid_map
      doc_id  = name2id[year]
      raise "[update_year] document not found for year=#{year} (name must be exactly '#{year}')" unless doc_id

      rows = article_collector.collect(label: 'update_year') do |post|
        created_year = post.respond_to?(:created_at) ? post.created_at&.year&.to_s : nil
        created_year == year
      end

      if rows.empty?
        warn "[update_year] no posts found for year=#{year}; only metadata will be touched (count=0)"
      end

      rows = maybe_summarize(rows, label: "update_year/#{year}")
      new_text = article_collector.compose_year_text(rows, delimiter: params[:chunking].delimiter)

      with_retry(params[:retries]) do
        dataset_client.update_document_by_text!(
          document_id: doc_id,
          name: year,
          text: new_text,
          process_rule: params[:chunking].process_rule
        )
        puts "[update_year] updated body for #{year} (#{doc_id}) items=#{rows.size}"
      end

      payload = [build_metadata_entry(doc_id, year, rows.size)]
      with_retry(params[:retries]) do
        dataset_client.update_documents_metadata!(payload)
        puts "[update_year] updated metadata for #{year} (#{doc_id})"
      end

      sleep params[:sleep_secs]
      puts "[update_year] done."
    end

    def popular_entries_report(limit: 20)
      entries = Entry.popular(limit: limit)

      lines = []
      lines << "[period: recent_30d] [last_updated_at: #{Date.today}]"
      lines << ""
      lines << "# Popular Entries (last 30 days)"

      entries.each.with_index(1) do |entry, i|
        lines << "#{i}. #{entry.title} - #{article_collector.build_url_for(entry)}"
        lines << "  published_at: #{entry.created_at}"
        lines << "  blurb: #{entry.summary}"
        lines << "  page_views: #{entry.pv}"
      end

      lines.join("\n")
    end

    private

    def default_sleep_secs
      (env['SLEEP_SECS'] || '7').to_f
    end

    def default_retries
      (env['RETRIES'] || '6').to_i
    end

    def default_chunk_delimiter
      "\n---\n\n"
    end

    def resolve_params(sleep_secs:, retries:, chunk_size:, chunk_delimiter:)
      chunk_size = 1200 if @summarize && chunk_size.nil? && env['CHUNK_SIZE'].nil?
      {
        sleep_secs: (sleep_secs || default_sleep_secs).to_f,
        retries: (retries || default_retries).to_i,
        chunking: build_chunking_config(chunk_size: chunk_size, chunk_delimiter: chunk_delimiter)
      }
    end

    def maybe_summarize(articles, label:)
      return articles unless @summarize

      @summarizer.summarize_all(articles, label: label)
    end

    def build_metadata_entry(doc_id, year, count)
      { document_id: doc_id, metadata: { 'period' => year, 'count' => count } }
    end

    def flush_batch_if_full!(batch, params, threshold: 10)
      return unless batch.size >= threshold

      with_retry(params[:retries]) { dataset_client.update_documents_metadata!(batch) }
      batch.clear
      sleep params[:sleep_secs]
    end

    def flush_remaining_metadata!(batch, params)
      return if batch.empty?

      with_retry(params[:retries]) { dataset_client.update_documents_metadata!(batch) }
    end

    def create_or_update_document!(year, text, name2id, params)
      doc_id = name2id[year]
      if doc_id
        with_retry(params[:retries]) do
          dataset_client.update_document_by_text!(document_id: doc_id, name: year, text: text, process_rule: params[:chunking].process_rule)
          puts "[refresh_yearly] updated #{year} (#{doc_id})"
        end
        doc_id
      else
        with_retry(params[:retries]) do
          new_id = dataset_client.create_document_by_text!(
            name: year,
            text: text,
            process_rule: params[:chunking].process_rule
          )
          name2id[year] = new_id
          puts "[refresh_yearly] created #{year} (#{new_id})"
          new_id
        end
      end
    end

    def build_chunking_config(chunk_size:, chunk_delimiter:)
      ChunkingConfig.new(
        chunk_size: chunk_size,
        chunk_delimiter: chunk_delimiter,
        default_delimiter: default_chunk_delimiter,
        env: env
      )
    end

    def build_name_to_docid_map
      dataset_client.list_all_documents.each_with_object({}) do |document, map|
        map[document['name'].to_s] = document['id']
      end
    end

    def with_retry(retries)
      tries = 0
      begin
        yield
      rescue StandardError => e
        tries += 1
        raise e if tries > retries
        backoff = (2**tries) * 0.5
        warn "retry(#{tries}) after #{backoff}s: #{e.class} #{e.message}"
        sleep backoff
        retry
      end
    end
  end
end
