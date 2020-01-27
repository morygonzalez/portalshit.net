# frozen_string_literal: true

module Lokka
  module AmazonAssociate
    class Fetcher
      include CacheControllable

      def initialize(item_id)
        @item_id = item_id
        @kind = :json
        wirite_or_touch_cache unless cache_alive?
      end

      def fetch
        sleep 1
        client = Vacuum.new(
          marketplace: 'JP',
          partner_tag: Option.associate_tag,
          access_key: Option.access_key_id,
          secret_key: Option.secret_key
        )
        resources = [
          'Images.Primary.Medium',
          'ItemInfo.ByLineInfo',
          'ItemInfo.Classifications',
          'ItemInfo.Title',
          'Offers.Listings.Price'
        ]
        client.get_items(item_ids: [@item_id], resources: resources)
      end

      def result
        fetch.to_h.to_json
      end
    end
  end
end
