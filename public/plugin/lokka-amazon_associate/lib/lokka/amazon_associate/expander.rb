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

        matches.each do |item_id|
          html = HtmlFormatter.new(item_id)
          base_url = "https://portalshit.net"
          iframe = %Q(<iframe src="#{base_url}/amazon/#{item_id}.html" />)
          body.gsub!(/<!--\s(?:ASIN|ISBN)=#{html.item_id}\s-->/, iframe)
        end

        body
      end
    end
  end
end
