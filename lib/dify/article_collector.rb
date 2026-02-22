# frozen_string_literal: true

require 'dify/article_formatter'

module Dify
  class ArticleCollector
    attr_reader :formatter, :scope

    def initialize(base_url:, scope: default_scope)
      @formatter = ArticleFormatter.new(base_url: base_url)
      @scope = scope
    end

    def collect(label:)
      rows = []

      scope.find_each do |post|
        next if block_given? && !yield(post)

        rows << formatter.article_hash(post)
      rescue StandardError => e
        warn "[#{label}] skip id=#{post.respond_to?(:id) ? post.id : 'n/a'}: #{e.class} #{e.message}"
      end

      rows
    end

    def collect_by_year(label:)
      rows = collect(label: label)
      rows.group_by { |h| extract_year(h[:date]) }
    end

    def count_by_year
      counts = Hash.new(0)
      scope.find_each do |post|
        y = post.respond_to?(:created_at) ? post.created_at&.year : nil
        next unless y

        year = y.to_s
        counts[year] += 1 if year.match?(/\A\d{4}\z/)
      end
      counts
    end

    def compose_year_text(posts, delimiter: nil)
      formatter.compose_year_text(posts, **(delimiter ? { delimiter: delimiter } : {}))
    end

    def build_url_for(post)
      formatter.build_url_for(post)
    end

    private

    def extract_year(date_str)
      year = date_str.to_s.slice(0, 4)
      year.match?(/\A\d{4}\z/) ? year : 'unknown'
    end

    def default_scope
      Entry.published.includes(:tags, :category)
    end
  end
end
