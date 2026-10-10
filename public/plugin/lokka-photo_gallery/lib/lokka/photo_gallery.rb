require 'date'

module Lokka
  module PhotoGallery
    RESOURCE_BASE_URL   = 'https://resources.portalshit.net'.freeze
    IMAGEPROXY_BASE_URL = 'https://portalshit.net/imageproxy'.freeze
    IMAGE_EXTENSIONS    = %w[jpg jpeg png gif].freeze
    THUMBNAIL_SIZE      = '115'.freeze
    COVER_SIZE          = '1280x'.freeze

    # クライアントから返ってくるメタデータのうち、テンプレートが読むキーだけを通す。
    RENDERABLE_KEYS = %i[
      filename s3_filename title width height alt taken_at url thumb_url
      camera lens f_number shutter_speed iso focal_length
      location licence_text licence_url keywords
    ].freeze

    def self.sort_by_filename(images)
      images.sort_by.with_index do |item, index|
        [filename_sort_key(item[:filename]), index]
      end
    end

    def self.sort_images(images, sort_by: nil)
      case sort_by.to_s
      when '', 'filename'
        sort_by_filename(images)
      when 'taken_at'
        images.sort_by.with_index do |item, index|
          time = capture_time(item[:taken_at])
          [time ? 0 : 1, time || 0, filename_sort_key(item[:filename]), index]
        end
      else
        raise ArgumentError, '並び順は filename または taken_at を指定してください'
      end
    end

    def self.capture_time(value)
      # EXIF の YYYY:MM:DD と従来の ISO 形式を扱う。時差のない値は日本時間。
      normalized = value.to_s.strip.sub(/\A(\d{4}):(\d{2}):(\d{2})/, '\\1-\\2-\\3')
      match = normalized.match(/\A(\d{4}-\d{2}-\d{2})(?:[T ](\d{2}:\d{2}:\d{2}(?:\.\d+)?))?(?:\s*(Z|[+-]\d{2}:?\d{2}))?\z/)
      return nil unless match
      return nil if match[2] && (match[2][0, 2].to_i > 23 || match[2][6, 2].to_i > 59)

      DateTime.iso8601("#{match[1]}T#{match[2] || '00:00:00'}#{match[3] || '+09:00'}").ajd
    rescue ArgumentError
      nil
    end

    def self.filename_sort_key(filename)
      filename.to_s.scan(/[0-9]+|[^0-9]+/).map do |part|
        part.match?(/\A[0-9]+\z/) ? [0, part.to_i] : [1, part.downcase]
      end
    end

    def self.registered(app)
      app.post '/admin/photo_gallery/photos' do
        content_type :json

        file = params[:file]
        halt 400, { message: 'ファイルがありません' }.to_json if file.blank?

        filename = file[:filename].to_s
        unless PhotoGallery::PhotoProcessor.image_extension?(filename)
          halt 400, { message: "対応していない画像形式です: #{filename}" }.to_json
        end

        begin
          status 201
          PhotoGallery::PhotoProcessor.
            new(do_upload: true).
            process(file[:tempfile].path, filename: filename).
            to_json
        rescue StandardError => e
          logger.error "[photo_gallery] #{e.class}: #{e.message}" if respond_to?(:logger) && logger
          halt 500, { message: e.message }.to_json
        end
      end

      app.post '/admin/photo_gallery/render' do
        content_type :json

        begin
          images = parse_gallery_images(params[:images], sort_by: params[:sort_by])
        rescue ArgumentError => e
          halt 400, { message: e.message }.to_json
        end
        halt 400, { message: '画像がありません' }.to_json if images.empty?

        { body: PhotoGallery::Renderer.new(images, cover_id: params[:cover_id]).render }.to_json
      end
    end
  end

  module Helpers
    def parse_gallery_images(raw, sort_by: nil)
      parsed = JSON.parse(raw.to_s, symbolize_names: true)
      return [] unless parsed.is_a?(Array)

      images = parsed.filter_map do |item|
        item.slice(*PhotoGallery::RENDERABLE_KEYS) if item.is_a?(Hash)
      end
      PhotoGallery.sort_images(images, sort_by: sort_by)
    rescue JSON::ParserError
      []
    end
  end
end

# 定数を参照するため、モジュール本体の定義後に読み込む。
require_relative 'photo_gallery/photo_processor'
require_relative 'photo_gallery/renderer'
