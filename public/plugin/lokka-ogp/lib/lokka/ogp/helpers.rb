# frozen_string_literal: true

module Lokka
  module OGP
    module Helpers
      def ogp
        hash = OGPHash.new(entry: @entry, site: @site, request: @request, theme: @theme)
        hash.generate
      end

      def twitter_card
        hash = TwitterCardHash.new(entry: @entry, site: @site, request: @request, theme: @theme)
        hash.generate
      end
    end
  end
end
