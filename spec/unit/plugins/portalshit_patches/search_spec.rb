# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search do
  describe '#search_type' do
    it 'returns :tag for tag: prefix' do
      expect(Search.new('tag:ruby').search_type).to eq(:tag)
    end

    it 'returns :tag for tags: prefix' do
      expect(Search.new('tags:ruby,rails').search_type).to eq(:tag)
    end

    it 'returns :category for category: prefix' do
      expect(Search.new('category:tech').search_type).to eq(:category)
    end

    it 'returns :all for plain text' do
      expect(Search.new('hello world').search_type).to eq(:all)
    end
  end

  describe '#query_type' do
    it 'returns :term_query for tag without spaces' do
      expect(Search.new('tag:ruby').query_type).to eq(:term_query)
    end

    it 'returns :phrase_query for tag with spaces' do
      expect(Search.new('tag:ruby on rails').query_type).to eq(:phrase_query)
    end

    it 'returns :phrase_query for tags with spaces' do
      expect(Search.new('tags:ruby, rails').query_type).to eq(:phrase_query)
    end

    it 'returns :facet_query for category' do
      expect(Search.new('category:tech').query_type).to eq(:facet_query)
    end

    it 'returns :smart_query for plain text' do
      expect(Search.new('hello world').query_type).to eq(:smart_query)
    end
  end

  describe '#keywords' do
    context 'tag search' do
      it 'splits by comma and lowercases' do
        search = Search.new('tag:Ruby,Rails,JS')
        expect(search.keywords).to eq(%w[ruby rails js])
      end

      it 'strips whitespace from tag names' do
        search = Search.new('tags:ruby , rails')
        expect(search.keywords).to eq(%w[ruby rails])
      end

      it 'returns empty array when no tags after prefix' do
        search = Search.new('tag:')
        expect(search.keywords).to eq([])
      end
    end

    context 'category search' do
      it 'prepends / to category name' do
        search = Search.new('category:tech')
        expect(search.keywords).to eq(['/tech'])
      end
    end

    context 'full text search' do
      it 'tokenizes query via Tokenizer' do
        allow(Tokenizer).to receive(:run).with('hello world').and_return(%w[hello world])
        search = Search.new('hello world')
        expect(search.keywords).to eq(['hello world'])
      end

      it 'falls back to raw query when tokenizer returns empty' do
        allow(Tokenizer).to receive(:run).with('test').and_return([])
        search = Search.new('test')
        expect(search.keywords).to eq(['test'])
      end

      it 'strips quotes from raw query fallback' do
        allow(Tokenizer).to receive(:run).with('"exact phrase"').and_return([])
        search = Search.new('"exact phrase"')
        expect(search.keywords).to eq(['exact phrase'])
      end
    end
  end

  describe '#fields' do
    it 'returns :tags for tag search' do
      expect(Search.new('tag:ruby').fields).to eq(:tags)
    end

    it 'returns :category for category search' do
      expect(Search.new('category:tech').fields).to eq(:category)
    end

    it 'returns multiple fields for full text search' do
      expect(Search.new('hello').fields).to eq(%i[title title_tokenized body category_tokenized tags])
    end
  end
end
