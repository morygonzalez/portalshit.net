require 'digest'
require_relative '../photo_gallery'
require_relative 'metadata_store'
require_relative 's3_uploader'
require_relative 'exif_extractor'
require_relative 'geocoder'

module Lokka
  module PhotoGallery
    class MetadataGenerator
      def initialize(folder, do_upload:)
        @folder = folder
        @do_upload = do_upload
        @store = MetadataStore.new(File.join(folder, 'metadata.json'))
        @uploader = S3Uploader.new if do_upload
      end

      def generate
        metadata = @store.read

        images = Dir.entries(@folder).select do |file|
          ext = File.extname(file).downcase.delete_prefix('.')
          IMAGE_EXTENSIONS.include?(ext)
        end

        image_hashes = images.map.with_index do |filename, index|
          filepath = File.join(@folder, filename)
          digest = Digest::MD5.file(filepath).to_s
          extname = File.extname(filepath)
          s3_filename = digest + extname

          processed_data = metadata.find { |item| item[:s3_filename] == s3_filename }

          if processed_data.present?
            processed_data
          else
            sleep 1 if index > 0
            @uploader.upload(filepath, s3_filename) if @do_upload

            exif = ExifExtractor.new(filepath).to_hash
            location_result = build_location(exif[:latitude], exif[:longitude])

            build_image_hash(filename, s3_filename, exif, location_result)
          end
        end

        @store.write(image_hashes)
        puts "Generated #{File.join(@folder, 'metadata.json')}"
      end

      private

      def build_location(latitude, longitude)
        if latitude && longitude
          Geocoder.reverse_geocode(latitude: latitude, longitude: longitude)
        else
          { location: nil, licence_text: nil, licence_url: nil, raw: nil }
        end
      end

      def build_image_hash(filename, s3_filename, exif, location_result)
        url = "#{RESOURCE_BASE_URL}/#{s3_filename}"
        thumb_url = "#{IMAGEPROXY_BASE_URL}/#{THUMBNAIL_SIZE}/#{url}"

        {
          filename: filename,
          s3_filename: s3_filename,
          title: exif[:title],
          width: exif[:width],
          height: exif[:height],
          alt: exif[:title],
          taken_at: exif[:taken_at],
          url: url,
          thumb_url: thumb_url,
          camera: exif[:camera],
          lens: exif[:lens],
          f_number: exif[:f_number],
          shutter_speed: exif[:shutter_speed],
          iso: exif[:iso],
          focal_length: exif[:focal_length],
          latitude: exif[:latitude],
          longitude: exif[:longitude],
          location: location_result[:location],
          licence_text: location_result[:licence_text],
          licence_url: location_result[:licence_url],
          reverse_geocode_raw: location_result[:raw],
          keywords: exif[:keywords]
        }
      end
    end
  end
end
