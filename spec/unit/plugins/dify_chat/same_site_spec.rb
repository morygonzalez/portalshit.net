# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lokka::DifyChat do
  describe '.same_site_request?' do
    def request_with(env)
      Sinatra::Request.new({ 'HTTP_HOST' => 'portalshit.net' }.merge(env))
    end

    it 'accepts an Origin from the site itself' do
      expect(described_class.same_site_request?(request_with('HTTP_ORIGIN' => 'https://portalshit.net'))).to be true
    end

    it 'accepts a Referer from the site itself' do
      expect(
        described_class.same_site_request?(request_with('HTTP_REFERER' => 'https://portalshit.net/2023/07/19/entry'))
      ).to be true
    end

    it 'accepts the www host' do
      expect(described_class.same_site_request?(request_with('HTTP_ORIGIN' => 'https://www.portalshit.net'))).to be true
    end

    # 開発環境 (localhost:3000) は self_hosts に無いので request.host で通す。
    it 'accepts the requested host itself' do
      expect(
        described_class.same_site_request?(
          request_with('HTTP_HOST' => 'localhost:3000', 'HTTP_ORIGIN' => 'http://localhost:3000')
        )
      ).to be true
    end

    it 'rejects a request without Origin and Referer' do
      expect(described_class.same_site_request?(request_with({}))).to be false
    end

    it 'rejects an Origin from another site' do
      expect(described_class.same_site_request?(request_with('HTTP_ORIGIN' => 'https://evil.example.com'))).to be false
    end

    it 'rejects a Referer from another site' do
      expect(
        described_class.same_site_request?(request_with('HTTP_REFERER' => 'https://evil.example.com/portalshit.net'))
      ).to be false
    end

    it 'prefers Origin over Referer' do
      expect(
        described_class.same_site_request?(
          request_with('HTTP_ORIGIN' => 'https://evil.example.com', 'HTTP_REFERER' => 'https://portalshit.net/')
        )
      ).to be false
    end

    it 'rejects an unparseable Origin' do
      expect(described_class.same_site_request?(request_with('HTTP_ORIGIN' => 'http://[bad'))).to be false
    end
  end
end
