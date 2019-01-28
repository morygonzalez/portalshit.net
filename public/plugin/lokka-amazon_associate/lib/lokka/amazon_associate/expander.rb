# frozen_string_literal: true

module Lokka
  module AmazonAssociate
    class Expander
      attr_reader :body

      def initialize(body)
        @body = body
      end

      def expand_associate_link
        matches = body.scan(/<!--\s(?:ASIN|ISBN)=(.+?)\s-->/).flatten
        return body if matches.blank?

        matches.each do |match|
          item = Item.new(match)
          partial = Formatter.new(item).format
          body.gsub!(/<!--\s(?:ASIN|ISBN)=#{match}\s-->/, partial)
        end

        body
      end
    end
  end
end
