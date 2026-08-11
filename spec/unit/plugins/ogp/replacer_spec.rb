# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lokka::OGP::Replacer do
  # Entry の保存で全文検索インデックス更新（MeCab）が走るが、この spec の
  # 対象ではないのでスタブする。
  before { allow(Search).to receive(:add) }

  describe 'self-hosted links' do
    it 'replaces a self-hosted link without ever touching Fetcher (no self HTTP request)' do
      entry = create(:post_with_slug)
      body = %(<p><a href="https://portalshit.net/#{entry.slug}">#{entry.title}</a></p>)

      expect(Lokka::OGP::Fetcher).not_to receive(:new)

      result = described_class.new(body).replace

      expect(result).to include('class="ogp"')
      expect(result).to include(entry.title)
    end

    it 'leaves the original link untouched when the self-hosted entry cannot be resolved' do
      body = '<p><a href="https://portalshit.net/no-such-entry">missing</a></p>'

      expect(Lokka::OGP::Fetcher).not_to receive(:new)

      result = described_class.new(body).replace

      expect(result).to include('href="https://portalshit.net/no-such-entry"')
      expect(result).not_to include('class="ogp"')
    end
  end

  describe 'external links' do
    it 'still fetches external links through Fetcher' do
      body = '<p><a href="https://example.com/article">external</a></p>'
      fake_fetcher = instance_double(Lokka::OGP::Fetcher, cached_html: '<div class="ogp">external card</div>')
      allow(Lokka::OGP::Fetcher).to receive(:new).with('https://example.com/article').and_return(fake_fetcher)

      result = described_class.new(body).replace

      expect(result).to include('external card')
    end

    it 'leaves the link untouched when Fetcher has nothing cached' do
      body = '<p><a href="https://example.com/article">external</a></p>'
      fake_fetcher = instance_double(Lokka::OGP::Fetcher, cached_html: nil)
      allow(Lokka::OGP::Fetcher).to receive(:new).with('https://example.com/article').and_return(fake_fetcher)

      result = described_class.new(body).replace

      expect(result).to include('href="https://example.com/article"')
      expect(result).not_to include('class="ogp"')
    end
  end

  it 'does not replace paragraphs with more than a single link' do
    body = '<p>see <a href="https://example.com/a">a</a> and <a href="https://example.com/b">b</a></p>'
    expect(Lokka::OGP::Fetcher).not_to receive(:new)

    result = described_class.new(body).replace

    expect(result).to include('href="https://example.com/a"')
    expect(result).to include('href="https://example.com/b"')
  end
end
