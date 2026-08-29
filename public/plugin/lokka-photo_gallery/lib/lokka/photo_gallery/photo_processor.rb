require 'digest'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require_relative '../photo_gallery'
require_relative 's3_uploader'
require_relative 'exif_extractor'
require_relative 'geocoder'

module Lokka
  module PhotoGallery
    # 画像 1 枚から EXIF 抽出・位置情報のマスク・S3 アップロード・逆ジオコーディングを
    # 行ってメタデータを組み立てる。フォルダ一括処理の MetadataGenerator と
    # 管理画面からの 1 枚ずつのアップロードの両方から使う。
    class PhotoProcessor
      def initialize(do_upload:)
        @do_upload = do_upload
        @uploader = S3Uploader.new if do_upload
      end

      # filename は S3 上の名前ではなく、記事に残す元のファイル名。
      # アップロード経由では tempfile のパスと元の名前が異なるため明示的に受け取る。
      def process(filepath, filename: nil)
        filename ||= File.basename(filepath)
        s3_filename = Digest::MD5.file(filepath).to_s + File.extname(filename).downcase

        exif = ExifExtractor.new(filepath).to_hash
        latitude, longitude = mask_private_location(exif[:latitude], exif[:longitude])

        upload(filepath, s3_filename, strip_gps: latitude.nil? && exif[:latitude]) if @do_upload

        location = build_location(latitude, longitude)
        build_image_hash(
          filename,
          s3_filename,
          exif.merge(latitude: latitude, longitude: longitude),
          location
        )
      end

      def self.image_extension?(filename)
        IMAGE_EXTENSIONS.include?(File.extname(filename).downcase.delete_prefix('.'))
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

      private

      def upload(filepath, s3_filename, strip_gps: false)
        return @uploader.upload(filepath, s3_filename) unless strip_gps

        Dir.mktmpdir do |tmpdir|
          tmp_path = File.join(tmpdir, File.basename(filepath))
          FileUtils.cp(filepath, tmp_path)
          system('exiftool', '-overwrite_original', '-gps:all=', tmp_path)
          @uploader.upload(tmp_path, s3_filename)
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

      def build_image_hash(filename, s3_filename, exif, location)
        url = "#{RESOURCE_BASE_URL}/#{s3_filename}"

        {
          filename: filename,
          s3_filename: s3_filename,
          title: exif[:title],
          width: exif[:width],
          height: exif[:height],
          alt: exif[:title],
          taken_at: exif[:taken_at],
          url: url,
          thumb_url: "#{IMAGEPROXY_BASE_URL}/#{THUMBNAIL_SIZE}/#{url}",
          camera: exif[:camera],
          lens: exif[:lens],
          f_number: exif[:f_number],
          shutter_speed: exif[:shutter_speed],
          iso: exif[:iso],
          focal_length: exif[:focal_length],
          latitude: exif[:latitude],
          longitude: exif[:longitude],
          location: location[:location],
          licence_text: location[:licence_text],
          licence_url: location[:licence_url],
          reverse_geocode_raw: location[:raw],
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
    end
  end
end
