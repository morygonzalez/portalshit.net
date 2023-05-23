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

  def nm
    require 'natto'
    @nm ||= Natto::MeCab.new(userdic: File.expand_path('lib/tokenizer/userdic.dic'))
  end

  def words
    @words ||= []
  end

  def tokenize
    nm.parse(cleansed_text) do |n|
      ignore_feature_regexp = /記号|動詞|数|助詞|副詞|形容詞|接尾|代名詞|非自立|接続詞|連体詞|接頭詞|BOS\/EOS/
      next if n.feature.match?(ignore_feature_regexp)
      next if n.surface.match?(/\A([0-9]+|[a-zA-Z]{1}|\p{hiragana}{1}|\p{katakana}{1})\Z/i) # 数字・アルファベット・平仮名・カタカナ一文字除去
      words << n.surface
    end

    words
  end
end
