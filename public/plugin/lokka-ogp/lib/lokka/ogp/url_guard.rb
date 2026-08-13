# frozen_string_literal: true

require 'faraday'
require 'ipaddr'
require 'resolv'
require 'timeout'
require 'uri'

module Lokka
  module OGP
    # OGP の取得先が「外部の公開サイト」かどうかを検証する。
    #
    # /api/chat/ogp のように第三者が URL を指定できる入口があるため、
    # http://127.0.0.1:8080/ や http://169.254.169.254/ を渡してサーバー内部を
    # 覗く SSRF を防ぐ。ホスト名の文字列だけでは判定できない（DNS で内部 IP を
    # 返すホスト名を用意されると素通りする）ので、名前解決した結果の IP を見る。
    module UrlGuard
      class UnsafeUrl < StandardError; end

      ALLOWED_SCHEMES = %w[http https].freeze

      # 標準ポート以外を塞ぐ。サーバー自身の公開 IP に対する
      # http://<公開IP>:8080/（imageproxy コンテナ）のような、IP レンジでは
      # 弾けない内部サービスへの到達を防ぐのが主目的。
      ALLOWED_PORTS = [80, 443].freeze

      # 到達させたくない IP レンジ。ループバック・プライベート・リンクローカル
      # （クラウドのメタデータ API を含む）・共有アドレス空間など。
      BLOCKED_RANGES = [
        '0.0.0.0/8',
        '10.0.0.0/8',
        '100.64.0.0/10',
        '127.0.0.0/8',
        '169.254.0.0/16',
        '172.16.0.0/12',
        '192.0.0.0/24',
        '192.0.2.0/24',
        '192.168.0.0/16',
        '198.18.0.0/15',
        '224.0.0.0/4',
        '240.0.0.0/4',
        '::/128',
        '::1/128',
        '64:ff9b::/96',
        'fc00::/7',
        'fe80::/10',
        'ff00::/8'
      ].map {|range| IPAddr.new(range) }.freeze

      RESOLV_TIMEOUT = 2

      class << self
        def safe?(url)
          ensure_safe!(url)
          true
        rescue UnsafeUrl
          false
        end

        # 検証を通れば URI を返し、通らなければ UnsafeUrl を投げる。
        # Faraday のミドルウェアから各リクエスト（リダイレクト先も含む）で呼ぶ。
        def ensure_safe!(url)
          uri = url.is_a?(URI::Generic) ? url : URI.parse(url.to_s)

          raise UnsafeUrl, "unsupported scheme: #{uri.scheme.inspect}" unless ALLOWED_SCHEMES.include?(uri.scheme)
          raise UnsafeUrl, "unsupported port: #{uri.port}" unless ALLOWED_PORTS.include?(uri.port)

          # URI#host は IPv6 だと角括弧付きの "[::1]" を返すので hostname を使う。
          host = uri.hostname.to_s
          raise UnsafeUrl, 'missing host' if host.empty?

          addresses = resolve(host)
          raise UnsafeUrl, "unresolvable host: #{host}" if addresses.empty?

          blocked = addresses.find {|address| blocked?(address) }
          raise UnsafeUrl, "blocked address: #{blocked} (#{host})" if blocked

          uri
        rescue URI::Error => e
          raise UnsafeUrl, e.message
        end

        private

        def blocked?(address)
          BLOCKED_RANGES.any? {|range| range.include?(address) }
        rescue IPAddr::Error
          true
        end

        # 名前解決に失敗したら空配列を返し、呼び出し側で不許可にする。
        # /etc/hosts も参照したいので Resolv::DNS ではなく Resolv を使う。
        def resolve(host)
          literal = ip_address(host)
          return [literal] if literal

          Timeout.timeout(RESOLV_TIMEOUT) do
            Resolv.getaddresses(host).filter_map {|address| ip_address(address) }
          end
        rescue StandardError
          []
        end

        def ip_address(value)
          IPAddr.new(value.to_s)
        rescue IPAddr::Error
          nil
        end
      end
    end

    # Faraday のリクエストごとに取得先を検証するミドルウェア。
    # follow_redirects より下に積むことで、リダイレクト先の URL も毎回検証される
    # （外部ホストから 127.0.0.1 へ 302 させる回避策を塞ぐ）。
    class SafeUrlMiddleware < Faraday::Middleware
      def call(env)
        UrlGuard.ensure_safe!(env.url)
        @app.call(env)
      end
    end
  end
end
