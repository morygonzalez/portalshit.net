# frozen_string_literal: true

module Lokka
  module AmazonAssociate
    class Item
      attr_reader :item_id

      def initialize(item_id)
        @item_id = item_id
      end

      def title
        @title ||= item_info['Title']['DisplayValue']
      end

      def link
        @link ||= item['DetailPageURL']
      end


      def image
        @image ||= begin
                     image_url = item.dig('Images', 'Primary', 'Medium', 'URL').presence
                     image_url || '/plugin/lokka-amazon_associate/assets/no-image.png'
                   end
      end

      def manufacturer
        @manufacturer ||= Value.new(item_info.dig('ByLineInfo', 'Manufacturer')).to_s
      end

      def contributors
        @contributors ||= item_info.dig('ByLineInfo', 'Contributors')
      end

      def binding
        @binding ||= Value.new(classifications['Binding'])
      end

      def product_group
        @product_group ||= Value.new(classifications['ProductGroup'])
      end

      def price
        @price ||= item.dig('Offers', 'Listings')[0]&.dig('Price', 'DisplayAmount') || 'Amazon で確認'
      end

      def author
        @author ||= contributors&.map {|contributor|
          Contributor.new(contributor).display_value
        }&.join(' / ')
      end

      private

      def response
        @response ||= Fetcher.new(item_id).body
      end

      def item
        @item ||= JSON.parse(response).dig('ItemsResult', 'Items')[0] || {}
      end

      def item_info
        @item_info ||= item['ItemInfo'] || {}
      end

      def classifications
        @classifications ||= item_info['Classifications']
      end
    end

    class Value
      attr_reader :value

      def initialize(value = {})
        @value = value || {}
      end

      def to_s
        display_value
      end

      def display_value
        value['DisplayValue']
      end

      def label
        value['Label']
      end

      def locale
        value['Locale']
      end
    end

    class Contributor
      attr_reader :contributor

      def initialize(contributor = {})
        @contributor = contributor
      end

      def display_value
        %(#{contributor['Name']} (#{contributor['Role']}))
      end
    end
  end
end
