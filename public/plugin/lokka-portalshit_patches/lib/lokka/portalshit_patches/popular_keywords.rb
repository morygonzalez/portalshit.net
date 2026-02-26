class PopularKeywords
  class << self
    def keywords(limit: 7)
      instance = self.new
      instance.unique
      instance.clean
      instance.sort
      instance.keywords.keys[0..limit]
    end
  end

  attr_reader :keywords

  def initialize
    @keywords = lines.
      split("\n").
      inject({}) {|result, line|
        line.match(/\A(\d+)?\s(.+)?\Z/)
        count = $1.to_i
        keyword = $2
        result[keyword] = count
        result
      }
  end

  def lines
    @lines ||=
      open(File.join(Lokka.root, '/public/log-aggregation/query-term-ranking-all.txt')).read
  end

  def unique
    @keywords = words.inject({}) {|result, keyword|
      original = keyword
      modified = keyword.gsub(/[[:punct:]]/, '').gsub(/\A[[:space:]]+\Z/, '').downcase
      count = if (@keywords[modified] && @keywords[original]) && (@keywords[modified] != @keywords[original])
                @keywords[modified].to_i + @keywords.delete(original)
              else
                @keywords.delete(original)
              end
      result[modified] = count
      result
    }
  end

  def clean
    @keywords = @keywords.reject {|key, value|
      key.blank? || value.blank? || key.length < 2 || key.length > 15
    }.reject {|key, value|
      begin
        Search.query(key).length.zero?
      rescue Tantiny::TantivyError, Tantiny::UnexpectedNone
        true
      end
    }
  end

  def sort
    @keywords = @keywords.sort_by {|_, value| -value }.to_h
  end

  def words
    @words ||= begin
                 words = @keywords.keys
                 words.reject {|word| words.any? {|_word| _word.include?(word) && word != _word }}
               end
  end
end
