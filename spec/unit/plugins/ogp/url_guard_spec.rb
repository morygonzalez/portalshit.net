# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lokka::OGP::UrlGuard do
  # 名前解決の結果に依存させないため、Resolv をスタブして判定ロジックだけを見る。
  def stub_resolv(host, *addresses)
    allow(Resolv).to receive(:getaddresses).with(host).and_return(addresses)
  end

  describe '.safe?' do
    it 'allows a normal external https url' do
      stub_resolv('example.com', '93.184.216.34')

      expect(described_class.safe?('https://example.com/entry')).to be true
    end

    it 'allows an ipv6 address outside the blocked ranges' do
      stub_resolv('example.com', '2606:2800:220:1:248:1893:25c8:1946')

      expect(described_class.safe?('https://example.com/entry')).to be true
    end

    it 'rejects loopback addresses given as a literal' do
      expect(described_class.safe?('http://127.0.0.1/')).to be false
      expect(described_class.safe?('http://[::1]/')).to be false
    end

    it 'rejects private addresses given as a literal' do
      expect(described_class.safe?('http://10.1.2.3/')).to be false
      expect(described_class.safe?('http://172.16.0.1/')).to be false
      expect(described_class.safe?('http://192.168.0.1/')).to be false
    end

    it 'rejects the cloud metadata endpoint' do
      expect(described_class.safe?('http://169.254.169.254/latest/meta-data/')).to be false
    end

    # ホスト名の文字列だけを見ていると素通りしてしまうパターン。
    it 'rejects a hostname that resolves to a private address' do
      stub_resolv('internal.example.com', '10.0.0.5')

      expect(described_class.safe?('https://internal.example.com/')).to be false
    end

    it 'rejects when any of the resolved addresses is blocked' do
      stub_resolv('mixed.example.com', '93.184.216.34', '127.0.0.1')

      expect(described_class.safe?('https://mixed.example.com/')).to be false
    end

    it 'rejects a host that cannot be resolved' do
      stub_resolv('nx.example.com')

      expect(described_class.safe?('https://nx.example.com/')).to be false
    end

    # サーバー自身の公開 IP に対する :8080（imageproxy コンテナ）などを塞ぐ。
    it 'rejects non-standard ports' do
      stub_resolv('example.com', '93.184.216.34')

      expect(described_class.safe?('http://example.com:8080/')).to be false
    end

    it 'allows explicit standard ports' do
      stub_resolv('example.com', '93.184.216.34')

      expect(described_class.safe?('https://example.com:443/')).to be true
    end

    it 'rejects schemes other than http/https' do
      expect(described_class.safe?('file:///etc/passwd')).to be false
      expect(described_class.safe?('gopher://example.com/')).to be false
    end

    it 'rejects urls without a host' do
      expect(described_class.safe?('/relative/path')).to be false
      expect(described_class.safe?('')).to be false
    end

    it 'rejects unparseable urls' do
      expect(described_class.safe?('http://[bad')).to be false
    end
  end

  describe '.ensure_safe!' do
    it 'returns the parsed uri when the url is safe' do
      stub_resolv('example.com', '93.184.216.34')

      expect(described_class.ensure_safe!('https://example.com/entry')).to be_a(URI::HTTPS)
    end

    it 'raises UnsafeUrl when the url is blocked' do
      expect { described_class.ensure_safe!('http://127.0.0.1/') }
        .to raise_error(described_class::UnsafeUrl, /blocked address/)
    end
  end
end

RSpec.describe Lokka::OGP::SafeUrlMiddleware do
  let(:app) { ->(env) { env } }
  let(:middleware) { described_class.new(app) }

  it 'passes through a safe url' do
    allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])
    env = double(url: URI.parse('https://example.com/'))

    expect(app).to receive(:call).with(env)

    middleware.call(env)
  end

  # リダイレクトで内部に飛ばされる経路を塞げていることの確認。
  # follow_redirects の下に積んでいるので、ホップごとにここを通る。
  it 'raises before calling the adapter for a blocked url' do
    env = double(url: URI.parse('http://127.0.0.1:80/'))

    expect(app).not_to receive(:call)

    expect { middleware.call(env) }.to raise_error(Lokka::OGP::UrlGuard::UnsafeUrl)
  end
end
