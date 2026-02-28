# frozen_string_literal: true

class Search
  class << self
    def query(query, limit = 10)
      instance = new(query, limit)
      instance.result
    end

    def relation(query, limit = 10)
      instance = new(query, limit)
      instance.relation
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

  def relation
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
              scope.
                where('MATCH (entries.title, entries.body) AGAINST (? IN NATURAL LANGUAGE MODE)', query).
                order(Arel.sql("MATCH (entries.title, entries.body) AGAINST (#{Entry.connection.quote(query)} IN NATURAL LANGUAGE MODE) DESC"))
            end

    scope = scope.limit(limit) if limit
    scope
  end

  def result
    relation.pluck(:id).map(&:to_s)
  end
end
