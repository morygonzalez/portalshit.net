# frozen_string_literal: true

module Lokka
  module OGP
    class Fetcher
      attr_reader :url

      def initialize(url)
        @url = url
      end

      def fetch
        return true if element.exist?

        # 同じ URL が同時に表示された場合、各リクエストが外部サイトへ OGP を
        # 取りに行くのを防ぐ。ロック取得後にキャッシュを再確認する。
        FileUtils.mkdir_p(Element::CACHE_DIR)
        File.open("#{cache_path}.lock", File::RDWR | File::CREAT, 0o644) do |lock|
          lock.flock(File::LOCK_EX)
          return true if element.exist?

          element.create
        end
      rescue URI::InvalidURIError => e
        puts e.message
      end

      def cached_html
        begin
          return unless fetch
        rescue StandardError
          # 有効期限後の再取得に失敗しても、以前の表示可能なキャッシュが
          # あればそれを返し、外部サイトの障害を 502 に波及させない。
          raise unless File.exist?(cache_path)
        end

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
