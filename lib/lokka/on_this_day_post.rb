# frozen_string_literal: true

module Lokka
  class OnThisDayPost
    ASSOCIATIONS = %i[category tags user public_comments].freeze
    CACHE_NAMESPACE = 'on_this_day_post_ids'

    def self.cache
      @cache ||= ActiveSupport::Cache::FileStore.new(
        File.join(Lokka.root, 'tmp', 'cache')
      )
    end

    def initialize(date: Time.current.to_date, cache: self.class.cache, random: Random)
      @date = date
      @cache = cache
      @random = random
    end

    def find
      id = candidate_ids.sample(random: @random)
      return unless id

      Post.published.includes(*ASSOCIATIONS).find_by(id: id)
    end

    private

    def candidate_ids
      @cache.fetch(cache_key) do
        Post.published.created_around_today(@date).reorder(nil).ids
      end
    end

    def cache_key
      "#{CACHE_NAMESPACE}/#{@date.year}/#{@date.strftime('%m%d')}"
    end
  end
end
