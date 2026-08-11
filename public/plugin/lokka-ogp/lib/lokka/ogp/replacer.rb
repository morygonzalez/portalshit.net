# frozen_string_literal: true

require 'parallel'

module Lokka
  module OGP
    class Replacer
      def initialize(body)
        @body = body
      end

      def doc
        @doc ||= Nokogiri::HTML.fragment(@body.encode('UTF-8', invalid: :replace, undef: :replace, replace: ''))
      end

      def replace
        @replaced ||=
          begin
            local, remote = candidates.partition {|_node, url| LocalEntry.self_host?(url) }

            replace_local(local)
            replace_remote(remote)

            doc.to_s.html_safe
          end
      end

      private

      # 自サイトは DB から解決する。ActiveRecord のコネクションプールを
      # 圧迫しないよう Parallel を使わずメインスレッドで処理する。記事が
      # 引けなければ何もせず素のリンクのまま残す。
      def replace_local(pairs)
        pairs.each do |node, url|
          html = LocalEntry.card_for_url(url)
          node.replace(html) if html.present?
        end
      end

      def replace_remote(pairs)
        # Parallel はブロックの arity が 2 だと (item, index) を渡すので、
        # 引数は 1 つで受けて中で分解する。
        Parallel.each(pairs, in_threads: 3) do |pair|
          node, url = pair
          html = Lokka::OGP::Fetcher.new(url).cached_html
          node.replace(html) if html.present?
        rescue StandardError => e
          # 1 本のリンクの取得失敗で記事全体を 500 にしない。
          puts "[lokka-ogp] failed to fetch OGP for #{url}: #{e.class}: #{e.message}"
        end
      end

      def candidates
        doc.xpath('./p').filter_map do |node|
          next if node.children.length > 1
          next if node.inner_html =~ %r{img src|video src}
          next if node.inner_html !~ %r|\A<a href.+?/a>\Z|

          url = node.xpath('./a').first.attributes['href'].value
          next if url.blank?

          [node, url]
        end
      end
    end
  end
end
