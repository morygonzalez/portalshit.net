require 'erb'
require_relative '../photo_gallery'

module Lokka
  module PhotoGallery
    class Renderer
      # cover_id には s3_filename を渡す。管理画面からはユーザーが選んだカバーを
      # 明示的に指定し、rake 経由では EXIF のキーワードから判定する。
      def initialize(images, cover_id: nil)
        @cover = find_cover(images, cover_id)
        @images = if @cover
                    images.reject { |item| item[:s3_filename] == @cover[:s3_filename] }
                  else
                    images
                  end
      end

      def render
        template = File.read(File.join(__dir__, 'template.erb'))
        ERB.new(template, trim_mode: '-').result(binding)
      end

      private

      def find_cover(images, cover_id)
        if cover_id.present?
          images.find { |item| item[:s3_filename] == cover_id }
        else
          images.find { |item| item[:keywords] =~ /cover/i }
        end
      end

      def image_src(item, cover: false)
        if cover
          "#{IMAGEPROXY_BASE_URL}/#{COVER_SIZE}/#{item[:url]}"
        else
          item[:thumb_url]
        end
      end

      def h(value)
        ERB::Util.html_escape(value)
      end
    end
  end
end
