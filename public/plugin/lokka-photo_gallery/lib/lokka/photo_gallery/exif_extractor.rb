require 'exiftool'

module Lokka
  module PhotoGallery
    class ExifExtractor
      def initialize(filepath)
        @exif = Exiftool.new(filepath).to_hash
      end

      def to_hash
        {
          title: @exif[:title],
          camera: "#{@exif[:make]} #{@exif[:model]}",
          lens: @exif[:lens_model],
          f_number: "ƒ/#{@exif[:f_number]}",
          shutter_speed: @exif[:shutter_speed],
          iso: @exif[:iso],
          focal_length: @exif[:focal_length],
          width: @exif[:image_width],
          height: @exif[:image_height],
          taken_at: @exif[:date_time_original],
          latitude: @exif[:gps_latitude],
          longitude: @exif[:gps_longitude],
          keywords: @exif[:subject]
        }
      end
    end
  end
end
