require 'tantiny'
require 'natto'

desc "Create full text search index"
task :create_search_index do
  entries = Entry.includes(:category, :tags).published

  index = Lokka::Helpers.search_index

  index.transaction do
    entries.each do |entry|
      body_cleansed = entry.raw_body.
        gsub(/<.+?>/, '').
        gsub(/!?\[.+?\)/, '').
        gsub(%r{(?:```|<code>)(.+?)(?:```|</code>)}m, '\1')

      words = []

      preserved_words.each do |word|
        words << word if body_cleansed.match?(word)
      end

      category_splitted = entry.category&.title&.split('/')&.join(' ')
      tags_splitted = entry.tag_list.join(' ')
      title_tokenized = tokenize(entry.title).join(' ')
      body_tokenized = (words + tokenize(body_cleansed)).join(' ')
      category_tokenized = tokenize(entry.category&.title).join(' ') if entry.category

      index << {
        id: entry.id,
        title: entry.title,
        title_tokenized: title_tokenized,
        category: category_splitted,
        category_tokenized: category_tokenized,
        tags: tags_splitted,
        body: body_tokenized,
        date: entry.created_at
      }
    end
  end

  index.reload
end

def preserved_words
  @preserved_words ||= %w[山と道 ハイキング 縦走 散歩 プログラミング]
end

def words_to_ignore
  @words_to_ignore ||= %w[
    これ こと とき よう そう やつ とこ ところ 用 もの はず みたい たち いま 後 確か 中 気 方
    頃 上 先 点 前 一 内 lt gt ここ なか どこ まま わけ ため 的 それ あと
  ]
end

def nm
  @nm ||= Natto::MeCab.new
end

def tokenize(text)
  words = []
  nm.parse(text) do |n|
    next unless n.feature.match?(/名詞/)
    next if n.feature.match?(/(サ変接続|数)/)
    next if n.surface.match?(/\A([a-z][0-9]|\p{hiragana}|\p{katakana})\Z/i)
    next if words_to_ignore.include?(n.surface)
    words << n.surface
  end
  words
end
