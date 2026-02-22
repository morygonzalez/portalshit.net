require 'json'
require 'fileutils'

module Lokka
  module PhotoGallery
    class MetadataStore
      def initialize(path)
        @path = path
      end

      def read
        text = read_or_create_file(default: JSON.dump([]))
        JSON.parse(text, symbolize_names: true)
      rescue JSON::ParserError
        []
      end

      def write(data)
        File.write(@path, JSON.pretty_generate(data))
      end

      private

      def read_or_create_file(default: "")
        FileUtils.mkdir_p(File.dirname(@path))

        content = nil
        File.open(@path, File::RDWR | File::CREAT, 0o644) do |f|
          f.flock(File::LOCK_EX)
          if f.size.zero?
            f.write(default)
            f.flush
          end
          f.rewind
          content = f.read
        end

        content
      end
    end
  end
end
