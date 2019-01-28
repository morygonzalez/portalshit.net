# frozen_string_literal: true

module Lokka
  module AmazonAssociate
    class Fetcher
      def initialize(item_id)
        @item_id = item_id
        wirite_or_touch_cache unless cache_alive?
      end

      def path
        @path ||= begin
                    dir = File.expand_path('tmp/amazon')
                    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
                    File.join(dir, "#{@item_id}.json")
                  end
      end

      def body
        @body ||= File.read(path)
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

      private

      def cache_alive?
        File.exist?(path) && File.stat(path).mtime > Time.now - 60 * 60 * 24
      end

      def wirite_or_touch_cache
        item = fetch
        File.open(path, 'w') {|f| f.print Hash.from_xml(item.doc.to_xml).to_json }
      rescue StandardError
        FileUtils.touch path
      end
    end
  end
end
