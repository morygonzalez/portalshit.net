# frozen_string_literal: true

module Lokka
  module AmazonAssociate
    class JsonFetcher
      include CacheControllable

      def initialize(item_id)
        @item_id = item_id
        @kind = :json
        wirite_or_touch_cache unless cache_alive?
      end

      def fetch(*args)
        args = { country: :jp, response_group: 'Medium' } if args.blank?
        Amazon::Ecs.options = {
          associate_tag: Option.associate_tag,
          AWS_access_key_id: Option.access_key_id,
          AWS_secret_key: Option.secret_key
        }
        Amazon::Ecs.item_lookup(@item_id, args)
      end

      def result
        item = fetch
        Hash.from_xml(item.doc.to_xml).to_json
      end
    end
  end
end
