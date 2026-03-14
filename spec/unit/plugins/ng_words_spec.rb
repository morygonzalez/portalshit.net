# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'NgWords helpers' do
  include Lokka::Helpers

  describe '#ng_words' do
    it 'parses comma-separated words' do
      allow(Option).to receive(:ng_words).and_return('spam, viagra, casino')
      expect(ng_words).to eq(%w[spam viagra casino])
    end

    it 'returns empty array when nil' do
      allow(Option).to receive(:ng_words).and_return(nil)
      expect(ng_words).to eq([])
    end
  end

  describe '#ok_languages' do
    it 'parses comma-separated language codes' do
      allow(Option).to receive(:ok_languages).and_return('en, ja')
      expect(ok_languages).to eq(%w[en ja])
    end

    it 'returns empty array when nil' do
      allow(Option).to receive(:ok_languages).and_return(nil)
      expect(ok_languages).to eq([])
    end
  end

  describe '#include_ng_words?' do
    before do
      allow(Option).to receive(:ng_words).and_return('spam, viagra')
    end

    it 'returns true when body contains an NG word' do
      allow(self).to receive(:comment_body).and_return('Buy cheap viagra now')
      expect(include_ng_words?).to be true
    end

    it 'is case insensitive' do
      allow(self).to receive(:comment_body).and_return('SPAM message')
      expect(include_ng_words?).to be true
    end

    it 'returns false when body has no NG words' do
      allow(self).to receive(:comment_body).and_return('Hello, nice post!')
      expect(include_ng_words?).to be false
    end

    it 'returns false with empty NG word list' do
      allow(Option).to receive(:ng_words).and_return(nil)
      allow(self).to receive(:comment_body).and_return('anything')
      expect(include_ng_words?).to be false
    end
  end

  describe '#other_than_ok_language?' do
    before do
      allow(Option).to receive(:ok_languages).and_return('en, ja')
    end

    it 'returns false when language is in OK list' do
      allow(CLD).to receive(:detect_language).and_return({ code: 'en' })
      allow(self).to receive(:comment_body).and_return('Hello world')
      expect(other_than_ok_language?).to be false
    end

    it 'returns true when language is not in OK list' do
      allow(CLD).to receive(:detect_language).and_return({ code: 'ru' })
      allow(self).to receive(:comment_body).and_return('Привет мир')
      expect(other_than_ok_language?).to be true
    end
  end

  describe '#is_it_spam?' do
    before do
      allow(Option).to receive(:ng_words).and_return('spam')
      allow(Option).to receive(:ok_languages).and_return('en, ja')
    end

    it 'returns true when body contains NG words' do
      allow(self).to receive(:comment_body).and_return('This is spam')
      allow(CLD).to receive(:detect_language).and_return({ code: 'en' })
      expect(is_it_spam?).to be true
    end

    it 'returns true when language is not OK' do
      allow(self).to receive(:comment_body).and_return('Clean text')
      allow(CLD).to receive(:detect_language).and_return({ code: 'ru' })
      expect(is_it_spam?).to be true
    end

    it 'returns false when clean and OK language' do
      allow(self).to receive(:comment_body).and_return('Nice post!')
      allow(CLD).to receive(:detect_language).and_return({ code: 'en' })
      expect(is_it_spam?).to be false
    end
  end
end
