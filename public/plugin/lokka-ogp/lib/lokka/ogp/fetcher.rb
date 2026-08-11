# frozen_string_literal: true

require 'timeout'

module Lokka
  module OGP
    class Fetcher
      attr_reader :url

      def initialize(url)
        @url = url
      end

      def fetch
        # 自ホスト宛は絶対に HTTP を発行しない。自己リクエストが Puma の
        # スレッドを食い潰して 504 になるため、カードは LocalEntry が DB から
        # 組み立てる。ここは呼び出し漏れに対する保険。
        return false if LocalEntry.self_host?(url)
        return true if element.exist?

        # 同じ URL が同時に表示された場合、各リクエストが外部サイトへ OGP を
        # 取りに行くのを防ぐ。ロック取得後にキャッシュを再確認する。
        FileUtils.mkdir_p(Element::CACHE_DIR)
        File.open("#{cache_path}.lock", File::RDWR | File::CREAT, 0o644) do |lock|
          # 他スレッドが取得中なら待たない。ロック待ちは下の Timeout の外側
          # なので、待つと Puma のスレッドが上限なく詰まる。既存のキャッシュが
          # あればそれで済ませ、なければ今回は諦める。
          return File.exist?(cache_path) unless lock.flock(File::LOCK_EX | File::LOCK_NB)
          return true if element.exist?

          # 外部サイトへの複数回の逐次リクエストが積み重なって Puma のスレッドを
          # 長時間占有しないよう、取得処理全体に上限時間を設ける。
          Timeout.timeout(8) { element.create }
        end
      rescue URI::InvalidURIError => e
        puts e.message
      end

      def cached_html
        begin
          return nil unless fetch
        rescue StandardError
          # 有効期限後の再取得に失敗しても、以前の表示可能なキャッシュが
          # あればそれを返し、外部サイトの障害を 502 に波及させない。
          raise unless File.exist?(cache_path)
        end
        return nil unless File.exist?(cache_path)

        File.read(cache_path)
      end

      def element
        @element ||= Element.new(url)
      end

      private

      def cache_path
        File.join(Element::CACHE_DIR, element.uname)
      end
    end
  end
end
