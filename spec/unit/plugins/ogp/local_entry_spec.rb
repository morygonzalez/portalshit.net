# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lokka::OGP::LocalEntry do
  # Entry の保存で全文検索インデックス更新（MeCab）が走るが、この spec の
  # 対象ではないのでスタブする。
  before { allow(Search).to receive(:add) }

  describe '.self_host?' do
    it 'is true for the default self host' do
      expect(described_class.self_host?('https://portalshit.net/2011/01/09/hello')).to be true
    end

    it 'is true for a www-prefixed self host' do
      expect(described_class.self_host?('https://www.portalshit.net/hello')).to be true
    end

    it 'is true for a relative path (no host)' do
      expect(described_class.self_host?('/2011/01/09/hello')).to be true
    end

    it 'is false for an external host' do
      expect(described_class.self_host?('https://example.com/article')).to be false
    end

    it 'is false for an invalid URL' do
      expect(described_class.self_host?('not a url')).to be false
    end

    it 'honors the current request host via RequestStore' do
      # Sinatra の request.host はポート番号を含まない。
      RequestStore[:ogp_self_host] = 'localhost'
      expect(described_class.self_host?('http://localhost:3000/hello')).to be true
    end
  end

  describe '.find_entry' do
    let!(:entry) { create(:post_with_slug) }

    it 'finds a published entry by slug' do
      found = described_class.find_entry('https://portalshit.net/welcome-lokka')
      expect(found).to eq(entry)
    end

    it 'finds a published entry by an absolute-path-only URL' do
      found = described_class.find_entry('/welcome-lokka')
      expect(found).to eq(entry)
    end

    it 'returns nil for a slug that does not exist' do
      expect(described_class.find_entry('https://portalshit.net/no-such-entry')).to be_nil
    end

    it 'returns nil for an unpublished entry' do
      draft = create(:post_with_slug, slug: 'draft-entry', publish_at: nil)
      expect(described_class.find_entry("https://portalshit.net/#{draft.slug}")).to be_nil
    end

    it 'returns nil for the site root' do
      expect(described_class.find_entry('https://portalshit.net/')).to be_nil
    end
  end

  describe 'card data' do
    let(:entry) do
      create(
        :post_with_slug,
        title: 'ローカル記事',
        body: '<p>本文です。</p><p><img src="https://portalshit.net/photo.jpg"></p>'
      )
    end
    let(:local) { described_class.new(entry, 'https://portalshit.net/welcome-lokka') }

    # Entry#body / #cover_image / #summary_or_description は lokka-ogp が
    # Replacer 実行に alias 差し替えしているため、これらを呼ぶと OGP の
    # 置換処理が再帰する。LocalEntry がこれらを一切呼ばないことを固定する。
    it 'never touches the aliased body/cover_image/summary_or_description methods' do
      expect(entry).not_to receive(:body)
      expect(entry).not_to receive(:short_body)
      expect(entry).not_to receive(:cover_image)
      expect(entry).not_to receive(:summary_or_description)
      expect(entry).not_to receive(:images)

      local.title
      local.description
      local.image
      local.html
    end

    it 'uses the entry title verbatim' do
      expect(local.title).to eq('ローカル記事')
    end

    it 'extracts the first image from the raw body' do
      expect(local.image).to eq('https://portalshit.net/photo.jpg')
    end

    it 'falls back to the default OGP image when the body has no image' do
      entry.update(body: '<p>image less</p>')
      no_image_local = described_class.new(entry, 'https://portalshit.net/welcome-lokka')
      expect(no_image_local.image).to eq(described_class::FALLBACK_IMAGE)
    end

    it 'prefers the summary column for description when present' do
      entry.update(summary: '要約テキスト')
      expect(local.description).to eq('要約テキスト')
    end

    it 'derives description from the body when summary is blank' do
      expect(local.description).to include('本文です')
    end

    it 'renders the same .ogp markup as external cards' do
      html = local.html
      expect(html).to include('class="ogp"')
      expect(html).to include('ローカル記事')
    end

    it 'does not hit the network while building the card' do
      expect(Faraday).not_to receive(:new)
      local.html
    end
  end

  describe '.card_for_url' do
    before { create(:post_with_slug) }

    it 'returns a card for a resolvable self URL' do
      html = described_class.card_for_url('https://portalshit.net/welcome-lokka')
      expect(html).to include('class="ogp"')
    end

    it 'returns nil when the entry cannot be resolved' do
      expect(described_class.card_for_url('https://portalshit.net/does-not-exist')).to be_nil
    end
  end
end
