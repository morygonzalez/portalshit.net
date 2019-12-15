# frozen_string_literal: true

module Lokka
  module AmazonAssociate
    class Item
      attr_reader :item_id

      def initialize(item_id)
        @item_id = item_id
      end

      def fetched_json
        @fetched_json ||= JsonFetcher.new(item_id)
      end

      def body
        @body ||= fetched_json.body
      end

      def item
        @item ||= JSON.parse(body).dig('ItemLookupResponse', 'Items', 'Item') || {}
      end

      def attributes
        @attributes ||= item['ItemAttributes'] || {}
      end

      def title
        @title ||= attributes['Title']
      end

      def link
        @link ||= item['DetailPageURL']
      end

      def image_set
        @image_set ||= item['ImageSets'] ? item.dig('ImageSets', 'ImageSet') : false
      end

      def image
        @image ||= case
                   when item['LargeImage']
                     item.dig('LargeImage', 'URL')
                   when image_set && image_set.length > 1
                     item.dig('ImageSets', 'ImageSet', 'URL')
                   when image_set && image_set.length == 1
                     image_set.dig('LargeImage', 'URL')
                   else
                     '/plugin/lokka-amazon_associate/assets/no-image.png'
                   end
      end

      def manufacturer
        @manufacturer ||= attributes['Brand'] || attributes['Manufacturer'] || attributes['Studio']
      end

      def binding
        @binding ||= attributes['Binding'] || attributes['ProductGroup'] || attributes['Format']
      end

      def price
        @price ||= case
                   when item.dig('OfferSummary', 'LowestNewPrice')
                     item.dig('OfferSummary', 'LowestNewPrice', 'FormattedPrice')
                   when item.dig('OfferSummary', 'LowestUsedPrice')
                     item.dig('OfferSummary', 'LowestUsedPrice', 'FormattedPrice')
                   when item.dig('OfferSummary', 'LowestCollectiblePrice')
                     item.dig('OfferSummary', 'LowestCollectiblePrice', 'FormattedPrice')
                   else
                     'Amazon で確認';
                   end
      end

      def author
        @author ||= begin
                      authors = []

                      authors.push(attributes['Creator'])  if attributes['Creator'].present?
                      authors.push(attributes['Author'])   if attributes['Author'].present?
                      authors.push(attributes['Director']) if attributes['Director'].present?
                      authors.push(attributes['Actor'])    if attributes['Actor'].present?
                      authors.push(attributes['Artist'])   if attributes['Artist'].present?

                      authors.flatten.join(', ')
                    end
      end
    end
  end
end
