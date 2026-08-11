# frozen_string_literal: true

module Lokka
  module OGP
    # 自サイトの URL は DB に元データがあるので、HTTP で自分自身に取りに行かず
    # Entry から直接 OGP カードを組み立てる。
    #
    # 自己リクエストは「記事を描画 → 本文中の自サイトリンクを HTTP 取得 →
    # その内側でまた記事を描画 → …」と再帰的に Puma のスレッドを食い潰し、
    # 504 の原因になっていた。自ホスト宛の HTTP を一切発行しないのが目的。
    class LocalEntry
      include Card

      DEFAULT_SELF_HOSTS = %w[portalshit.net www.portalshit.net].freeze
      FALLBACK_IMAGE = 'https://portalshit.net/theme/portalshit/ogp_image.png'
      IMAGE_EXTENSIONS = %w[jpg jpeg png gif].freeze
      DESCRIPTION_LENGTH = 100

      class << self
        # 自ホスト宛かどうか。ホストを持たない相対 URL も自サイト扱いにする。
        def self_host?(url)
          host = URI.parse(url.to_s).host
          return true if host.blank?

          self_hosts.include?(host.downcase)
        rescue URI::Error, ArgumentError
          false
        end

        # 既定値に加えて、環境変数と実際のリクエストホストも自ホストとみなす。
        # 後者があるので開発環境の localhost:3000 は設定なしで対象になる。
        def self_hosts
          hosts = ENV['OGP_SELF_HOSTS'].to_s.split(',').map {|host| host.strip.downcase }.reject(&:empty?)
          hosts = DEFAULT_SELF_HOSTS.dup if hosts.empty?
          request_host = RequestStore[:ogp_self_host]
          hosts << request_host.to_s.downcase if request_host.present?
          hosts.uniq
        end

        # 自サイトの URL からカード HTML を返す。記事が引けなければ nil を返し、
        # 呼び出し側は素のリンクのまま残す（自ホストへ HTTP は出さない）。
        def card_for_url(url)
          entry = find_entry(url)
          return nil if entry.nil?

          card_for_entry(entry, url)
        end

        def card_for_entry(entry, url = nil)
          return nil if entry.nil?

          url ||= entry.link
          return new(entry, url).html unless RequestStore.active?

          # 一覧ページで同じ記事が複数回リンクされても Markup のレンダリングを
          # 1 回で済ませる。リクエスト外ではメモ化せずメモリを溜めない。
          cards = (RequestStore[:ogp_local_cards] ||= {})
          cards[[entry.id, url]] ||= new(entry, url).html
        end

        def find_entry(url)
          path = URI.parse(url.to_s).path.to_s.sub(%r{/\z}, '')
          return nil if path.empty? || path == '/'

          entry = Entry.get_by_fuzzy_slug(path.sub(%r{\A/}, '')) || permalink_entry(path)
          return nil unless entry.respond_to?(:published?) && entry.published?

          entry
        rescue URI::Error, ArgumentError
          nil
        end

        private

        def permalink_entry(path)
          return nil unless Lokka::PermalinkHelper.custom_permalink?

          Lokka::PermalinkHelper.custom_permalink_entry(path)
        rescue StandardError
          nil
        end
      end

      attr_reader :entry, :url

      def initialize(entry, url = nil)
        @entry = entry
        @url = url || entry.link
      end

      def html
        card_html.html_safe
      end

      def title
        entry.title.to_s
      end

      # Entry#body / #images / #cover_image / #summary_or_description は
      # lokka-ogp 自身が Replacer 実行に alias 差し替えしているため、ここで
      # 呼ぶと OGP 置換が再帰する。alias の影響を受けない long_body と
      # 素のカラムだけを使うこと。
      def description
        source = entry.summary.presence || text_body
        source.to_s.gsub(/\s+/, ' ').strip[0, DESCRIPTION_LENGTH].to_s
      end

      def image
        @image ||= first_image_in_body || FALLBACK_IMAGE
      end

      def image_url
        secure_image
      end

      def host
        @host ||=
          begin
            URI.parse(url).host.presence || self.class.self_hosts.first
          rescue URI::Error, ArgumentError
            self.class.self_hosts.first
          end
      end

      private

      def body_doc
        @body_doc ||= Nokogiri::HTML.fragment(entry.long_body.to_s)
      end

      def text_body
        doc = body_doc.dup
        doc.css('script, style').each(&:remove)
        doc.text
      end

      def first_image_in_body
        body_doc.css('img, video').filter_map {|item|
          src = item.name == 'img' ? item['src'] : item['poster']
          next if src.blank?
          next if src.include?('/og-image/')

          src
        }.find {|src| IMAGE_EXTENSIONS.any? {|ext| src.downcase.end_with?(".#{ext}") } }
      end
    end
  end
end
