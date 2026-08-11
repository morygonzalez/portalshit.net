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
