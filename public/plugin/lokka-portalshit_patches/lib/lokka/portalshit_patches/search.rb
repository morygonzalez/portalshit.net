require 'tokenizer'

class Search
  INDEX_MUTEX = Mutex.new

  class << self
    # Tantiny::Index は 1 プロセスに 1 つだけ持つ。開くたびにファイル
    # ディスクリプタと mmap を消費するので、二重生成は避ける。
    #
    # 初回参照まで遅らせているのは、preload_app! を使っていると
    # クラス定義時＝fork 前の master で開くことになるため。worker 側で
    # 開き直すほうが fork を跨いだ状態の継承がなく安全で、テスト実行時に
    # 実インデックスを開いてしまう副作用もなくなる。
    def index
      @index || INDEX_MUTEX.synchronize { @index ||= build_index }
    end

    def query(query, limit = 10)
      instance = self.new(query, limit)
      instance.result
    end

    def add(entry)
      tags_splitted = entry.tag_list.join(' ')
      title_tokenized = Tokenizer.run(entry.title).join(' ')
      body_tokenized = Tokenizer.run(entry.raw_body).join(' ')
      category_tokenized = Tokenizer.run(entry.category.title).join(' ') if entry.category

      index << {
        id: entry.id,
        title: entry.title,
        title_tokenized: title_tokenized,
        category: "/#{entry.category&.title}",
        category_tokenized: category_tokenized,
        tags: tags_splitted,
        body: body_tokenized,
        date: entry.created_at
      }

      index.reload
    end

    private

    def build_index
      Tantiny::Index.new(Lokka::App.search_index_path) do
        id :id
        string :title
        text :title_tokenized
        facet :category
        text :category_tokenized
        text :tags
        text :body
        date :date
      end
    end
  end

  attr_reader :query, :limit, :query_type

  def initialize(query, limit = nil)
    @query = query
    @limit = limit
  end

  def search_type
    @search_type = if query =~ /category:/
                     :category
                   elsif query =~ /tags?:/
                     :tag
                   else
                     :all
                   end
  end

  def query_type
    @query_type = if query =~ /tags?:/
                    if query =~ /\s/
                      :phrase_query
                    else
                      :term_query
                    end
                  elsif query =~ /category:/
                    :facet_query
                  else
                    :smart_query
                  end
  end

  def keywords
    case
    when search_type == :tag
      query.match(/tags?:(.+)/)
      tags = $1
      return [] if tags.nil?
      tags.split(",").map(&:strip).map(&:downcase)
    when search_type == :all
      tokenized = Tokenizer.run(query)
      if tokenized.any?
        [tokenized.join(' ')]
      else
        [query.delete('"')]
      end
    when search_type == :category
      query.match(/category:(.+?)(?:\s|\z)/)
      ["/#{$1}"]
    else
      keywords = [Tokenizer.run(query)].flatten
      keywords << query if keywords.length > 1
      keywords
    end
  end

  def fields
    case search_type
    when :tag
      :tags
    when :category
      :category
    else
      %i[title title_tokenized body category_tokenized tags]
    end
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

  private

  def index
    Search.index
  end
end
