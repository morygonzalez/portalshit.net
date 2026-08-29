require_relative '../photo_gallery'
require_relative 'metadata_store'
require_relative 'photo_processor'

module Lokka
  module PhotoGallery
    class MetadataGenerator
      def initialize(folder, do_upload:)
        @folder = folder
        @store = MetadataStore.new(File.join(folder, 'metadata.json'))
        @processor = PhotoProcessor.new(do_upload: do_upload)
      end

      def generate
        metadata = @store.read

        images = Dir.entries(@folder).select { |file| PhotoProcessor.image_extension?(file) }

        # Nominatim への間隔は Geocoder 側で保証しているため、ここでは待たない。
        image_hashes = images.map do |filename|
          filepath = File.join(@folder, filename)
          s3_filename = Digest::MD5.file(filepath).to_s + File.extname(filename).downcase
          processed_data = metadata.find { |item| item[:s3_filename] == s3_filename }

          processed_data.presence || @processor.process(filepath, filename: filename)
        end

        @store.write(image_hashes)
        puts "Generated #{File.join(@folder, 'metadata.json')}"
      end
    end
  end
end
