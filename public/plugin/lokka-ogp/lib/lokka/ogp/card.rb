# frozen_string_literal: true

require 'erb'

module Lokka
  module OGP
    # OGP カードの HTML と画像 URL の組み立て。外部サイトを HTTP で取得する
    # Element と、自サイトの記事を DB から解決する LocalEntry で共有する。
    # 両者がまったく同じマークアップを吐くことで、テーマの CSS を変えずに済む。
    #
    # インクルード先に url / title / description / image / host が必要。
    module Card
      IMAGEPROXY_BASE_URL = 'https://portalshit.net/imageproxy/200'
      PROXY_EXCLUDE_REGEXP = /(githubusercontent|=\d|token=\w+)/.freeze

      TEMPLATE = <<~ERUBY
        <div class="ogp">
          <a href="<%= ERB::Util.html_escape(url) %>" class="ogp-link" target="_parent">
            <div class="ogp-element">
              <div class="ogp-image">
                <img src="<%= ERB::Util.html_escape(secure_image) %>" alt="<%= ERB::Util.html_escape(title) %>" />
              </div>
              <div class="ogp-summary">
                <h3><%= ERB::Util.html_escape(title) %></h3>
                <p class="description"><%= ERB::Util.html_escape(description) %></p>
                <p class="host"><%= ERB::Util.html_escape(host) %></p>
              </div>
            </div>
          </a>
        </div>
      ERUBY

      private

      def card_html
        ERB.new(TEMPLATE).result(binding)
      end

      def secure_image
        use_proxy? ? "#{IMAGEPROXY_BASE_URL}/#{image}" : image
      end

      def use_proxy?
        image.to_s.start_with?('http') && !image.to_s.match(PROXY_EXCLUDE_REGEXP)
      end
    end
  end
end
