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
        return if pairs.empty?

        # 同じ URL が本文中に複数回ある場合や、前後記事と類似記事の両方に
        # 現れる場合でも、1 リクエスト中の外部取得は一度だけにする。
        # RequestStore はスレッドローカルなので、メインスレッドで Hash を取得し、
        # Parallel の処理結果を戻してから更新する。
        request_cache = (RequestStore[:ogp_remote_cards] ||= {}) if RequestStore.active?

        urls = pairs.map(&:last).uniq
        cached = if request_cache
                   urls.select {|url| request_cache.key?(url) }.
                     to_h {|url| [url, request_cache[url]] }
                 else
                   {}
                 end
        uncached_urls = urls - cached.keys

        # Parallel はブロックの arity が 2 だと (item, index) を渡すので、
        # 引数は 1 つで受けて中で分解する。
        fetched = Parallel.map(uncached_urls, in_threads: 3) do |url|
          html = begin
                   Lokka::OGP::Fetcher.new(url).cached_html
                 rescue StandardError => e
                   # 1 本のリンクの取得失敗で記事全体を 500 にしない。
                   puts "[lokka-ogp] failed to fetch OGP for #{url}: #{e.class}: #{e.message}"
                   nil
                 end
          [url, html]
        end

        fetched = fetched.to_h
        request_cache.merge!(fetched) if request_cache
        html_by_url = cached.merge(fetched)

        pairs.each do |node, url|
          html = html_by_url[url]
          node.replace(html) if html.present?
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
