module Lokka
  module AmazonAssociate
    class Fetcher
      attr_reader :body

      def initialize(item_id)
        @item_id = item_id
        @path    = get_path
        wirite_or_touch_cache unless cache_alive?
        @body    = parse_item
      end

      def get_path
        dir = File.expand_path("tmp/amazon")
        FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
        path = File.join(dir, "#{@item_id}.json")
      end

      def fetch(*args)
        args = {:country => :jp, :response_group => 'Medium'} if args.blank?
        Amazon::Ecs.options = {
          :associate_tag     => Option.associate_tag,
          :AWS_access_key_id => Option.access_key_id,
          :AWS_secret_key    => Option.secret_key
        }
        Amazon::Ecs.item_lookup(@item_id, args)
      end

      def cache_alive?
        File.exists?(@path) && File.stat(@path).mtime > Time.now - 60 * 60 * 24
      end

      def wirite_or_touch_cache
        if item = fetch
          File.open(@path, "w") {|f|
            f.print Hash.from_xml(item.doc.to_xml).to_json
            sleep 1
          }
        else
          FileUtils.touch @path
        end
      end

      def parse_item
        JSON.parse(File.read(@path))
      end

      private :wirite_or_touch_cache, :cache_alive?
    end
  end
end
