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
          iframe = %Q(<iframe src="/#{html.path}" />)
          body.gsub!(/<!--\s(?:ASIN|ISBN)=#{item_id}\s-->/, iframe)
        end

        body
      end
    end
  end
end
