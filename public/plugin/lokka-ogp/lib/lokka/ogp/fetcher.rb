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
        element.create
      rescue URI::InvalidURIError => e
        puts e.message
      end

      def element
        @element ||= Element.new(url)
      end
    end
  end
end
