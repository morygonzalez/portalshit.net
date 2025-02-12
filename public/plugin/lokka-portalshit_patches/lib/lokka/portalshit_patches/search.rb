require 'tokenizer'

class Search
  class << self
    def query(query, limit = 10)
      instance = self.new(query, limit)
      instance.result
    end
  end

  attr_reader :query, :limit, :query_type

  def initialize(query, limit = nil)
    @query = query
    @limit = limit
  end

  def index
    @index ||= Lokka::App.search_index
  end

  def query_type
    @query_type = if query =~ /".+"/
                    :term_query
                  else
                    :smart_query
                  end
  end

  def keywords
    case query_type
    when :term_query
      [query.delete('"')]
    else
      keywords = [Tokenizer.run(query)].flatten
      keywords << query if keywords.length > 1
      keywords
    end
  end

  def fields
    %i[title title_tokenized body category category_tokenized tags]
  end

  def exec_query(keyword)
    index.send(query_type, fields, keyword)
  end

  def queries
    case keywords.length
    when 0
      index.empty_query
    when 1
      exec_query(keywords[0])
    else
      original_keyword = keywords.pop
      keywords.inject(exec_query(original_keyword)) do |query, keyword|
        query.|(exec_query(keyword))
      end
    end
  end

  def result
    if limit
      index.search(queries, limit: limit)
    else
      index.search(queries)
    end
  end
end
