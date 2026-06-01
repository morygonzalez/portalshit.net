require 'digest'
require 'tmpdir'
require 'fileutils'
require 'yaml'
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

            exif = ExifExtractor.new(filepath).to_hash
            lat, lng = mask_private_location(exif[:latitude], exif[:longitude])

            if @do_upload
              upload_file(filepath, s3_filename, strip_gps: lat.nil? && exif[:latitude])
            end

            location_result = build_location(lat, lng)
            build_image_hash(filename, s3_filename, exif.merge(latitude: lat, longitude: lng), location_result)
          end
        end

        @store.write(image_hashes)
        puts "Generated #{File.join(@folder, 'metadata.json')}"
      end

      private

      def upload_file(filepath, s3_filename, strip_gps: false)
        if strip_gps
          Dir.mktmpdir do |tmpdir|
            tmp_path = File.join(tmpdir, File.basename(filepath))
            FileUtils.cp(filepath, tmp_path)
            system('exiftool', '-overwrite_original', '-gps:all=', tmp_path)
            @uploader.upload(tmp_path, s3_filename)
          end
        else
          @uploader.upload(filepath, s3_filename)
        end
      end

      def mask_private_location(latitude, longitude)
        return [latitude, longitude] unless latitude && longitude

        private_zones = self.class.filtered_locations
        return [latitude, longitude] if private_zones.empty?

        in_private_zone = private_zones.any? do |zone|
          haversine_distance(latitude, longitude, zone[:latitude], zone[:longitude]) <= zone[:radius]
        end

        in_private_zone ? [nil, nil] : [latitude, longitude]
      end

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

      def haversine_distance(lat1, lng1, lat2, lng2)
        r = 6_371_000 # Earth's radius in meters
        lat1_rad = lat1 * Math::PI / 180
        lat2_rad = lat2 * Math::PI / 180
        delta_lat = (lat2 - lat1) * Math::PI / 180
        delta_lng = (lng2 - lng1) * Math::PI / 180
        a = Math.sin(delta_lat / 2)**2 +
            Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(delta_lng / 2)**2
        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        r * c
      end

      def self.filtered_locations
        return @filtered_locations if defined?(@filtered_locations)

        config_path = File.join(Lokka.root, 'config', 'filtered_locations.yml')
        return @filtered_locations = [] unless File.exist?(config_path)

        raw = YAML.safe_load(File.read(config_path), permitted_classes: [Symbol]) || []
        @filtered_locations = raw.select { |loc| loc.is_a?(Hash) }.filter_map do |loc|
          lat = loc['latitude']&.to_f
          lng = loc['longitude']&.to_f
          next nil unless lat && lng && lat != 0 && lng != 0

          { latitude: lat, longitude: lng, radius: (loc['radius'] || 300).to_f }
        end
      end
    end
  end
end
