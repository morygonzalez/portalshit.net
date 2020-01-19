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
          iframe = <<~HTML
            <iframe
               src="#{base_url}/amazon/#{item_id}.html"
               title="#{html.item.title}" scrolling="no" frameborder="0"
               style="display: block; width: 100%; height: 320px; max-width: 800px; margin: 10px 0px;">
            </iframe>
          HTML
          body.gsub!(/<!--\s(?:ASIN|ISBN)=#{html.item_id}\s-->/, iframe)
        end

        body
      end
    end
  end
end
