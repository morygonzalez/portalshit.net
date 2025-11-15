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
      rescue => e
        warn "[#{label}] skip id=#{post.respond_to?(:id) ? post.id : 'n/a'}: #{e.class} #{e.message}"
      end

      rows
    end

    def compose_year_text(posts, delimiter: nil)
      if delimiter.nil?
        formatter.compose_year_text(posts)
      else
        formatter.compose_year_text(posts, delimiter: delimiter)
      end
    end

    def build_url_for(post)
      formatter.build_url_for(post)
    end

    private

    def default_scope
      Entry.published.includes(:tags, :category)
    end
  end
end
