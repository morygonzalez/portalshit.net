# frozen_string_literal: true

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
      articles.map.with_index do |article, i|
        if article[:content].to_s.length <= @max_chars
          puts "[#{label}] skip(short) #{article[:title]}"
          article
        else
          puts "[#{label}] summarize (#{i + 1}/#{articles.size}) #{article[:title]}"
          summarized = summarize_one(article)
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
