# frozen_string_literal: true

class Search
  class << self
    def query(query, limit = 10)
      instance = new(query, limit)
      instance.result
    end
  end

  attr_reader :query, :limit

  def initialize(query, limit = nil)
    @query = query
    @limit = limit
  end

  def search_type
    @search_type ||= if query =~ /category:/
                       :category
                     elsif query =~ /tags?:/
                       :tag
                     else
                       :all
                     end
  end

  def result
    scope = Entry.published
    scope = case search_type
            when :category
              query.match(/category:(.+?)(?:\s|\z)/)
              category_name = $1
              scope.joins(:category).where(categories: { title: category_name })
            when :tag
              query.match(/tags?:(.+)/)
              tag_names = $1&.split(",")&.map(&:strip) || []
              scope.joins(:tags).where(tags: { name: tag_names })
            else
              scope.where('MATCH (entries.title, entries.body) AGAINST (? IN BOOLEAN MODE)', query)
            end

    scope = scope.limit(limit) if limit
    scope.pluck(:id).map(&:to_s)
  end
end
