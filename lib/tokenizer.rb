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
      あと 気 逆 方 （ ）
      ¥ gt lt ·  —
    ]
  end

  def preserved_words
    @preserved_words ||= %w[
      山と道 はてブ 鐘撞山 高祖山 叶岳 高地山 はてなブックマーク はてな 牛丼 心拍 心拍数 関連記事
      情報量 ARC'TERYX 三苫 博多駅
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
      next if words_to_ignore.include?(n.surface)
      ignore_feature_regexp = /記号|動詞|数|助詞|副詞|形容詞|接尾|代名詞|非自立|接続詞|連体詞|接頭詞|BOS\/EOS/
      next if n.feature.match?(ignore_feature_regexp)
      next if n.surface.match?(%r{[ -/:-@\[-~]}) # 記号除外
      next if n.surface.match?(/\A([0-9]+|[a-zA-Z]|\p{hiragana}|\p{katakana})\Z/i) # 数字・アルファベット・平仮名・カタカナ一文字除去
      words << n.surface
    end

    words
  end
end
