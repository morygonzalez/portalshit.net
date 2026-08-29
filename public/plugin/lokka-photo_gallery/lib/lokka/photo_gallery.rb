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
          PhotoGallery::PhotoProcessor
            .new(do_upload: true)
            .process(file[:tempfile].path, filename: filename)
            .to_json
        rescue StandardError => e
          logger.error "[photo_gallery] #{e.class}: #{e.message}" if respond_to?(:logger) && logger
          halt 500, { message: e.message }.to_json
        end
      end

      app.post '/admin/photo_gallery/render' do
        content_type :json

        images = parse_gallery_images(params[:images])
        halt 400, { message: '画像がありません' }.to_json if images.empty?

        { body: PhotoGallery::Renderer.new(images, cover_id: params[:cover_id]).render }.to_json
      end
    end
  end

  module Helpers
    def parse_gallery_images(raw)
      parsed = JSON.parse(raw.to_s, symbolize_names: true)
      return [] unless parsed.is_a?(Array)

      parsed
        .filter_map { |item| item.slice(*PhotoGallery::RENDERABLE_KEYS) if item.is_a?(Hash) }
        .sort_by { |item| item[:taken_at].to_s }
    rescue JSON::ParserError
      []
    end
  end
end

# 定数を参照するため、モジュール本体の定義後に読み込む。
require_relative 'photo_gallery/photo_processor'
require_relative 'photo_gallery/renderer'
