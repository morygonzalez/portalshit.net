# frozen_string_literal: true

require 'set'
require 'date'
require 'erb'

require 'dify/dataset_client'
require 'dify/article_collector'
require 'dify/chunking_config'

module Dify
  class KnowledgeExporter
    DEFAULT_SLEEP_SECS      = (ENV['SLEEP_SECS'] || '7').to_f
    DEFAULT_RETRIES         = (ENV['RETRIES'] || '6').to_i
    DEFAULT_CHUNK_DELIMITER = "\n---\n\n"

    attr_reader :api_base, :dataset_id, :dataset_token, :base_url, :state_file,
                :dataset_client, :article_collector, :env

    def initialize(
      api_base: ENV.fetch('DIFY_API_BASE', 'https://api.dify.ai'),
      dataset_id: ENV['DATASET_ID'],
      dataset_token: ENV['DATASET_API_KEY'],
      base_url: (ENV['BASE_URL'] || '').sub(%r{/\z}, ''),
      state_file: ENV['STATE_FILE'] || '.dify_uploaded_names',
      env: ENV
    )
      @api_base = api_base
      @dataset_id = dataset_id
      @dataset_token = dataset_token
      @base_url = base_url
      @state_file = state_file
      @env = env

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

    def default_sleep_secs
      DEFAULT_SLEEP_SECS
    end

    def default_retries
      DEFAULT_RETRIES
    end

    def default_chunk_delimiter
      DEFAULT_CHUNK_DELIMITER
    end

    def upload_yearly!(sleep_secs: nil, retries: nil, chunk_size: nil, chunk_delimiter: nil)
      dataset_client.ensure_credentials!

      sleep_secs = (sleep_secs || default_sleep_secs).to_f
      retries    = (retries    || default_retries).to_i
      chunking   = build_chunking_config(chunk_size: chunk_size, chunk_delimiter: chunk_delimiter)

      rows = article_collector.collect(label: 'upload_yearly')
      groups = rows.group_by { |h| (h[:date] || '').slice(0, 4) || 'unknown' }

      done = if File.exist?(state_file)
               File.readlines(state_file, chomp: true).to_set
             else
               Set.new
             end

      File.open(state_file, 'a') do |state|
        batch = []
        groups.sort.each do |year, items|
          name = year
          if done.include?(name)
            puts "[upload_yearly] skip (done): #{name}"
            next
          end

          text = article_collector.compose_year_text(items, delimiter: chunking.delimiter)
          with_retry(retries) do
            doc_id = dataset_client.create_document_by_text!(
              name: name,
              text: text,
              date: "#{year}-01-01",
              process_rule: chunking.process_rule
            )
            batch << { document_id: doc_id, metadata: { 'period' => year, 'count' => items.size } }
            puts "[upload_yearly] ok #{name} (#{doc_id}) items=#{items.size}"
          end

          state.puts(name)
          state.flush
          sleep sleep_secs

          next unless batch.size >= 10

          dataset_client.update_documents_metadata!(batch)
          batch.clear
          sleep sleep_secs
        rescue Interrupt
          warn "[upload_yearly] interrupted by user"; raise
        rescue => e
          warn "[upload_yearly] skip #{name}: #{e.class} #{e.message}"
        end

        dataset_client.update_documents_metadata!(batch) unless batch.empty?
      end

      puts "[upload_yearly] done. state: #{state_file}"
    end

    def refresh_yearly!(sleep_secs: nil, retries: nil)
      dataset_client.ensure_credentials!

      sleep_secs = (sleep_secs || default_sleep_secs).to_f
      retries    = (retries    || default_retries).to_i

      rows = article_collector.collect(label: 'refresh_yearly')
      groups = rows.group_by { |h| (h[:date] || '').slice(0, 4) || 'unknown' }

      name2id = build_name_to_docid_map

      batch = []
      groups.sort.each do |year, items|
        name = year
        text = article_collector.compose_year_text(items)

        doc_id = name2id[name]
        if doc_id
          with_retry(retries) do
            dataset_client.update_document_by_text!(document_id: doc_id, name: name, text: text)
            puts "[refresh_yearly] updated #{name} (#{doc_id}) items=#{items.size}"
          end
        else
          with_retry(retries) do
            doc_id = dataset_client.create_document_by_text!(
              name: name,
              text: text,
              date: "#{year}-01-01",
              process_rule: nil
            )
            name2id[name] = doc_id
            puts "[refresh_yearly] created #{name} (#{doc_id}) items=#{items.size}"
          end
        end

        batch << { document_id: doc_id, metadata: { 'period' => year, 'count' => items.size } }

        if batch.size >= 10
          with_retry(retries) { dataset_client.update_documents_metadata!(batch) }
          batch.clear
          sleep sleep_secs
        end

        sleep sleep_secs
      rescue Interrupt
        warn "[refresh_yearly] interrupted by user"; raise
      rescue => e
        warn "[refresh_yearly] skip #{name}: #{e.class} #{e.message}"
      end

      with_retry(retries) { dataset_client.update_documents_metadata!(batch) } unless batch.empty?

      puts "[refresh_yearly] done."
    end

    def repair_year_metadata!(batch_size: nil)
      dataset_client.ensure_credentials!

      batch_size = (batch_size || 20).to_i

      name2id = build_name_to_docid_map

      counts = Hash.new(0)
      Entry.published.includes(:tags, :category).find_each do |post|
        y = (post.respond_to?(:created_at) ? post.created_at&.year : nil)
        next unless y
        y = y.to_s
        counts[y] += 1 if y.match?(/\A\d{4}\z/)
      end

      missing = counts.keys.reject { |y| name2id.key?(y) }.sort
      warn "[repair] WARNING: not found for years: #{missing.join(', ')}" unless missing.empty?

      payloads = counts.sort.filter_map do |(year, cnt)|
        doc_id = name2id[year]
        next unless doc_id
        { document_id: doc_id, metadata: { 'period' => year, 'count' => cnt } }
      end

      if payloads.empty?
        puts "[repair] nothing to update"
        return
      end

      payloads.each_slice(batch_size) do |slice|
        res = dataset_client.update_documents_metadata!(slice)
        puts "[repair] updated #{slice.size} docs (status=#{res.code})"
        sleep 1.0
      rescue => e
        warn "[repair] slice failed: #{e.class} #{e.message}"
      end

      puts "[repair] done."
    end

    def update_year!(year:, sleep_secs: nil, retries: nil, chunk_size: nil, chunk_delimiter: nil)
      dataset_client.ensure_credentials!

      year       = (year || Time.now.year.to_s).to_s
      sleep_secs = (sleep_secs || default_sleep_secs).to_f
      retries    = (retries    || default_retries).to_i
      chunking   = build_chunking_config(chunk_size: chunk_size, chunk_delimiter: chunk_delimiter)

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

      new_text = article_collector.compose_year_text(rows, delimiter: chunking.delimiter)

      with_retry(retries) do
        dataset_client.update_document_by_text!(
          document_id: doc_id,
          name: year,
          text: new_text,
          process_rule: chunking.process_rule
        )
        puts "[update_year] updated body for #{year} (#{doc_id}) items=#{rows.size}"
      end

      payload = [{ document_id: doc_id, metadata: { 'period' => year, 'count' => rows.size } }]
      with_retry(retries) do
        dataset_client.update_documents_metadata!(payload)
        puts "[update_year] updated metadata for #{year} (#{doc_id})"
      end

      sleep sleep_secs
      puts "[update_year] done."
    end

    def popular_entries_report(limit: 20)
      entries = Entry.popular(limit: limit)
      template = <<~ERUBY
        [period: recent_30d] [last_updated_at: <%= Date.today %>]

        # Popular Entries (last 30 days)
        <% entries.each.with_index(1) do |entry, i| %>
          <%= i %>. <%= entry.title %> - <%= article_collector.build_url_for(entry) %>
            published_at: <%= entry.created_at %>
            blurb: <%= entry.summary %>
            page_views: <%= entry.pv %>
        <% end %>
      ERUBY
      erb = ERB.new(template)
      erb.result(binding)
    end

    private

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
      rescue => e
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
