# frozen_string_literal: true

ENV['NEWRELIC_AGENT_ENABLED'] = 'false'

module SimilarEntriesTask
  @stale_entry_ids = []

  class << self
    attr_accessor :stale_entry_ids
  end
end

class ExecutionDetector
  attr_reader :force, :message

  def initialize(arguments: {})
    @force = arguments[:force]
  end

  def run_execution?
    case
    when force.present? && force == 'true'
      SimilarEntriesTask.stale_entry_ids = Entry.published.pluck(:id)
      @message = "Force execution: processing all #{SimilarEntriesTask.stale_entry_ids.count} entries."
      true
    when Similarity.count.zero? || EntryEmbedding.count.zero?
      SimilarEntriesTask.stale_entry_ids = Entry.published.pluck(:id)
      @message = 'Run execution because there is no similarity/embedding records.'
      true
    when stale_entry_ids.empty?
      @message = 'Skip: no entries have been updated since last run.'
      false
    else
      SimilarEntriesTask.stale_entry_ids = stale_entry_ids
      @message = "Updating similarity for #{stale_entry_ids.count} changed entries..."
      true
    end
  end

  private

  def stale_entry_ids
    @stale_entry_ids ||= begin
      embedded_at = EntryEmbedding
        .select(:entry_id, :entry_updated_at)
        .each_with_object({}) { |r, h| h[r.entry_id] = r.entry_updated_at }

      Entry.published.pluck(:id, :updated_at).filter_map { |id, updated_at|
        id if embedded_at[id].nil? || embedded_at[id] < updated_at
      }
    end
  end
end

desc 'Detect and update similar entries'
task :similar_entries, :force do |task, arguments|
  detector = ExecutionDetector.new(arguments: arguments)
  if detector.run_execution?
    puts detector.message
    Rake::Task[:'similar_entries:generate_embeddings'].invoke
    Rake::Task[:'similar_entries:compute_similarities'].invoke
  else
    puts detector.message
    next
  end
end

namespace :similar_entries do
  EMBEDDING_MODEL = ENV.fetch('OPENAI_EMBEDDING_MODEL', 'text-embedding-3-small')
  BATCH_SIZE = 100

  def openai_client
    @openai_client ||= begin
      require 'openai'
      OpenAI::Client.new(access_token: ENV.fetch('OPENAI_API_KEY'))
    end
  end

  # text-embedding-3-small の上限は 8191 tokens
  # 日本語は概ね 1 文字 ≒ 1 token なので 8000 文字で切り詰める
  MAX_CHARS = 8000

  def entry_text(entry)
    text = [
      entry.title,
      entry.raw_body,
      entry.category&.title,
      entry.tag_list.join(' ')
    ].compact.join("\n").strip
    text.length > MAX_CHARS ? text[0, MAX_CHARS] : text
  end

  def fetch_embeddings_with_retry(texts, max_retries: 3)
    retries = 0
    begin
      response = openai_client.embeddings(
        parameters: {
          model: EMBEDDING_MODEL,
          input: texts
        }
      )

      if response['error']
        raise "OpenAI API error: #{response['error']['message']}"
      end

      response
    rescue Faraday::BadRequestError => e
      puts "  400 Bad Request detail: #{e.response&.dig(:body)}"
      raise
    rescue => e
      retries += 1
      if retries <= max_retries
        wait = 2 ** retries
        puts "  API error: #{e.message}. Retrying in #{wait}s (attempt #{retries}/#{max_retries})..."
        sleep wait
        retry
      else
        raise
      end
    end
  end

  desc 'Generate embeddings via OpenAI API'
  task :generate_embeddings do
    stale_ids = SimilarEntriesTask.stale_entry_ids
    puts "Generating embeddings for #{stale_ids.count} entries..."

    Entry.includes(:category, :tags).published.where(id: stale_ids).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      texts = batch.map { |entry| entry_text(entry) }

      puts "  Fetching embeddings for entries: #{batch.map(&:id).join(', ')}"
      response = fetch_embeddings_with_retry(texts)

      upsert_data = response['data'].map.with_index do |item, i|
        entry = batch[i]
        {
          entry_id: entry.id,
          embedding: item['embedding'].to_json,
          model: EMBEDDING_MODEL,
          token_count: response.dig('usage', 'total_tokens'),
          entry_updated_at: entry.updated_at
        }
      end

      EntryEmbedding.upsert_all(upsert_data)
    end

    puts "Embeddings generated."
  end

  desc 'Compute cosine similarities and update similarities table'
  task :compute_similarities do
    stale_ids = SimilarEntriesTask.stale_entry_ids
    puts "Computing similarities for #{stale_ids.count} entries..."

    # Load all embeddings
    all_embeddings = EntryEmbedding.all.each_with_object({}) do |ee, h|
      h[ee.entry_id] = ee.embedding_vector
    end

    if all_embeddings.empty?
      puts "No embeddings found. Run generate_embeddings first."
      next
    end

    entry_ids = all_embeddings.keys
    vectors   = all_embeddings.values

    similarities = []

    stale_ids.each do |target_id|
      target_vec = all_embeddings[target_id]
      next unless target_vec

      scores = entry_ids.map.with_index do |other_id, i|
        next if other_id == target_id
        score = target_vec.zip(vectors[i]).sum { |a, b| a * b }
        [other_id, score]
      end.compact

      top10 = scores.sort_by { |_, score| -score }.first(10)
      top10.each do |similar_entry_id, score|
        similarities << { entry_id: target_id, similar_entry_id: similar_entry_id, score: score }
      end
    end

    Similarity.where(entry_id: stale_ids).delete_all
    Similarity.insert_all(similarities) if similarities.any?

    puts "Similarities computed: #{similarities.count} records saved."
  end
end
