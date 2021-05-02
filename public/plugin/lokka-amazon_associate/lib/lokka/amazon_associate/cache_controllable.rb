module Lokka
  module AmazonAssociate
    module CacheControllable
      def path
        @path ||= begin
                    dir = File.expand_path("tmp/amazon/#{@kind}")
                    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
                    File.join(dir, "#{@item_id}.#{@kind}")
                  end
      end

      def body
        @body ||= File.read(path)
      end

      private

      def result
        raise NotImplementedError, 'The method #result should be implemented in an included class'
      end

      def cache_alive?
        return false unless File.exist?(path)
        return true if File.mtime(path) > Time.now - 60 * 60 * 24
        !File.zero?(path)
      end

      def wirite_or_touch_cache
        raise StandardError if result.nil?
        File.open(path, 'w') {|f| f.print result }
      rescue StandardError
        FileUtils.touch path
      end
    end
  end
end
