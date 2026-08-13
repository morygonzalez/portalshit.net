# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe Lokka::OGP::Fetcher do
  # Element#initialize は渡された URL 文字列に force_encoding するため、
  # frozen_string_literal のまま渡すと FrozenError になる。
  let(:external_url) { +'https://example.com/lokka-ogp-fetcher-spec' }
  let(:fetcher) { described_class.new(external_url) }
  let(:cache_dir) { Lokka::OGP::Element::CACHE_DIR }
  let(:cache_path) { File.join(cache_dir, fetcher.element.uname) }
  let(:lock_path) { "#{cache_path}.lock" }

  before { FileUtils.mkdir_p(cache_dir) }

  after do
    File.delete(cache_path) if File.exist?(cache_path)
    File.delete(lock_path) if File.exist?(lock_path)
  end

  # 未キャッシュの URL では取得可否の判定で名前解決が走るため、既定では
  # 外部の公開サイト扱いにしておく。
  before { allow(Lokka::OGP::UrlGuard).to receive(:safe?).and_return(true) }

  describe '#fetch' do
    it 'never builds/fetches an Element for a self-hosted URL (no self HTTP request)' do
      self_fetcher = described_class.new(+'https://portalshit.net/anything')

      expect(self_fetcher.element).not_to receive(:create)
      expect(self_fetcher.fetch).to be false
    end

    it 'does not block on a held lock and falls back to the existing cache' do
      File.write(cache_path, '<div class="ogp">cached</div>')
      lock_file = File.open(lock_path, File::RDWR | File::CREAT, 0o644)
      lock_file.flock(File::LOCK_EX)

      begin
        expect(fetcher.element).not_to receive(:create)

        result = Timeout.timeout(2) { fetcher.fetch }

        expect(result).to be true
      ensure
        lock_file.flock(File::LOCK_UN)
        lock_file.close
      end
    end

    it 'does not block on a held lock and gives up when there is no cache yet' do
      lock_file = File.open(lock_path, File::RDWR | File::CREAT, 0o644)
      lock_file.flock(File::LOCK_EX)

      begin
        expect(fetcher.element).not_to receive(:create)

        result = Timeout.timeout(2) { fetcher.fetch }

        expect(result).to be_falsey
      ensure
        lock_file.flock(File::LOCK_UN)
        lock_file.close
      end
    end

    it 'does not fetch a url that fails the SSRF guard' do
      allow(Lokka::OGP::UrlGuard).to receive(:safe?).with(external_url).and_return(false)

      expect(fetcher.element).not_to receive(:create)
      expect(fetcher.fetch).to be false
    end
  end

  describe '#existing_html' do
    it 'returns the cached content without issuing any request' do
      File.write(cache_path, '<div class="ogp">cached</div>')

      expect(fetcher).not_to receive(:fetch)
      expect(fetcher.element).not_to receive(:create)
      expect(fetcher.existing_html).to eq('<div class="ogp">cached</div>')
    end

    # 第三者が任意の URL を投げても外部へ HTTP が飛ばないこと（踏み台対策）。
    it 'returns nil without fetching when nothing is cached' do
      expect(fetcher).not_to receive(:fetch)
      expect(fetcher.element).not_to receive(:create)
      expect(fetcher.existing_html).to be_nil
    end

    it 'returns a stale cache instead of refetching it' do
      File.write(cache_path, '<div class="ogp">stale</div>')
      File.utime(2.months.ago.to_time, 2.months.ago.to_time, cache_path)

      expect(fetcher.element).not_to receive(:create)
      expect(fetcher.existing_html).to eq('<div class="ogp">stale</div>')
    end
  end

  describe '#cached_html' do
    it 'returns nil when nothing is cached and fetch fails' do
      allow(fetcher).to receive(:fetch).and_return(false)
      expect(fetcher.cached_html).to be_nil
    end

    it 'returns the cached content when fetch succeeds' do
      File.write(cache_path, '<div class="ogp">cached</div>')
      allow(fetcher).to receive(:fetch).and_return(true)
      expect(fetcher.cached_html).to eq('<div class="ogp">cached</div>')
    end
  end
end
