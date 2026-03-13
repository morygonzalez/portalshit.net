# frozen_string_literal: true

require 'digest'
require 'openai'

module Dify
  class ArticleSummarizer
    MODEL = 'gpt-5-mini'
    DEFAULT_MAX_CHARS = 800

    PROMPT = <<~PROMPT
      以下のブログ記事を%d文字以内の日本語で要約してください。
      プレーンテキストのみで返してください（JSON やマークダウンは不要）。

      %s
    PROMPT

    def initialize(max_chars: DEFAULT_MAX_CHARS, sleep_secs: 1.0, api_key: ENV['OPENAI_API_KEY'])
      @max_chars = max_chars
      @sleep_secs = sleep_secs
      @client = OpenAI::Client.new(access_token: api_key)
    end

    def summarize_all(articles, label:)
      cache = load_cache(articles)

      articles.map.with_index do |article, i|
        content = article[:content].to_s
        if content.length <= @max_chars
          puts "[#{label}] skip(short) #{article[:title]}"
          article
        elsif (cached = cache[article[:id]]) && cached[:content_hash] == content_hash(content)
          puts "[#{label}] skip(cached) #{article[:title]}"
          article.merge(content: cached[:summary])
        else
          puts "[#{label}] summarize (#{i + 1}/#{articles.size}) #{article[:title]}"
          summarized = summarize_one(article)
          save_cache(article[:id], content, summarized[:content])
          sleep @sleep_secs if i < articles.size - 1
          summarized
        end
      end
    end

    def summarize_one(article)
      text = call_openai(article[:content])
      article.merge(content: text)
    rescue StandardError => e
      warn "[summarize] failed for #{article[:title]}: #{e.class} #{e.message}; truncating"
      article.merge(content: truncate(article[:content]))
    end

    private

    def content_hash(text)
      Digest::SHA256.hexdigest(text.to_s)
    end

    def load_cache(articles)
      entry_ids = articles.map { |a| a[:id] }.compact
      return {} if entry_ids.empty?

      ::EntrySummary.where(entry_id: entry_ids).each_with_object({}) do |es, h|
        h[es.entry_id] = { content_hash: es.content_hash, summary: es.summary }
      end
    end

    def save_cache(entry_id, original_content, summary_text)
      return unless entry_id

      es = ::EntrySummary.find_or_initialize_by(entry_id: entry_id)
      es.update!(summary: summary_text, content_hash: content_hash(original_content))
    rescue StandardError => e
      warn "[summarize_cache] failed to save cache for entry_id=#{entry_id}: #{e.class} #{e.message}"
    end

    def call_openai(content)
      response = @client.responses.create(
        parameters: {
          model: MODEL,
          input: format(PROMPT, @max_chars, content),
          reasoning: { effort: 'minimal' }
        }
      )
      text = response.dig('output', 1, 'content', 0, 'text').to_s.strip
      raise 'empty response from OpenAI' if text.empty?

      text
    end

    def truncate(text)
      return text if text.length <= @max_chars

      cut = text[0, @max_chars]
      last_period = cut.rindex(/[。.!\n]/)
      last_period ? cut[0..last_period] : cut
    end
  end
end
