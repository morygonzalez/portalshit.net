# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Dify chat API' do
  include_context 'in site'

  # Element#initialize は URL に force_encoding するため、frozen な文字列を
  # 渡すと FrozenError になる。
  let(:external_url) { +'https://example.com/dify-chat-ogp-spec' }
  let(:fetcher) { Lokka::OGP::Fetcher.new(external_url) }
  let(:cache_path) { File.join(Lokka::OGP::Element::CACHE_DIR, fetcher.element.uname) }

  after { File.delete(cache_path) if File.exist?(cache_path) }

  def get_ogp(url, headers = { 'HTTP_REFERER' => 'https://portalshit.net/' })
    get "/api/chat/ogp?url=#{CGI.escape(url)}", {}, { 'HTTP_HOST' => 'portalshit.net' }.merge(headers)
  end

  describe 'GET /api/chat/ogp' do
    it 'rejects a request that does not come from the site' do
      get_ogp(external_url, {})

      expect(last_response.status).to eq(403)
    end

    it 'rejects a request refered from another site' do
      get_ogp(external_url, 'HTTP_REFERER' => 'https://evil.example.com/')

      expect(last_response.status).to eq(403)
    end

    # 踏み台対策の本丸。キャッシュに無い URL を渡しても外部へ HTTP を出さない。
    it 'never fetches an uncached url' do
      expect_any_instance_of(Lokka::OGP::Fetcher).not_to receive(:fetch)
      expect_any_instance_of(Lokka::OGP::Element).not_to receive(:create)

      get_ogp(external_url)

      expect(last_response.status).to eq(404)
    end

    it 'returns the card built from the existing cache' do
      FileUtils.mkdir_p(Lokka::OGP::Element::CACHE_DIR)
      File.write(cache_path, <<~HTML)
        <div class="ogp">
          <div class="ogp-image"><img src="https://example.com/image.png" /></div>
          <div class="ogp-summary">
            <h3>Cached title</h3>
            <p class="description">Cached description</p>
            <p class="host">example.com</p>
          </div>
        </div>
      HTML

      get_ogp(external_url)

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['title']).to eq('Cached title')
      expect(json['description']).to eq('Cached description')
      expect(json['image']).to eq('https://example.com/image.png')
      expect(json['host']).to eq('example.com')
    end

    it 'rejects a non-http url' do
      get_ogp('file:///etc/passwd')

      expect(last_response.status).to eq(400)
    end
  end

  describe 'POST /api/chat/messages' do
    # Dify のクレジットを第三者に消費されないこと。
    it 'rejects a request that does not come from the site' do
      post '/api/chat/messages',
           JSON.dump(query: 'hello', user: 'someone'),
           'HTTP_HOST' => 'portalshit.net', 'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(403)
    end

    it 'rejects a cross site Origin' do
      post '/api/chat/messages',
           JSON.dump(query: 'hello', user: 'someone'),
           'HTTP_HOST' => 'portalshit.net',
           'HTTP_ORIGIN' => 'https://evil.example.com',
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(403)
    end
  end
end
