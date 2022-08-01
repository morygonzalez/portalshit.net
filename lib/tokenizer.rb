class Tokenizer
  attr_reader :text

  class << self
    def run(text)
      self.new(text).tokenize
    end
  end

  def initialize(text)
    @text = text
  end

  def cleansed_text
    @cleansed_ ||= text.
      gsub(/<.+?>/, '').
      gsub(/!?\[(.+)?\].+?\)/, '\1').
      gsub(%r{(?:```|<code>)(.+?)(?:```|</code>)}m, '\1')
  end

  def words_to_ignore
    @words_to_ignore ||= %w[
      これ こと とき よう そう やつ とこ ところ もの はず みたい たち いま 確か
      頃 lt gt ここ なか どこ まま わけ ため 的 それ これ あれ まえ あと 以上 以前 以下 以後
    ]
  end

  def preserved_words
    @preserved_words ||= %w[
      山と道 はてブ 鐘撞山 はてなブックマーク はてな 牛丼
    ]
  end

  def nm
    require 'natto'
    @nm ||= Natto::MeCab.new
  end

  def words
    @words ||= []
  end

  def tokenize
    preserved_words.each do |word|
      words << word if cleansed_text.match?(word)
    end

    nm.parse(cleansed_text) do |n|
      next unless n.feature.match?(/名詞/)
      next if n.feature.match?(/数/)
      next if n.surface.match?(/\A([a-z][0-9]|\p{hiragana}|\p{katakana})\Z/i)
      next if words_to_ignore.include?(n.surface)
      words << n.surface
    end

    words
  end
end
