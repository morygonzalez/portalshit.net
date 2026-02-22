require_relative '../photo_gallery'

module Lokka
  module PhotoGallery
    class Renderer
      def initialize(images)
        @cover = images.find { |item| item[:keywords] =~ /cover/i }
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

      def image_src(item, cover: false)
        if cover
          "#{IMAGEPROXY_BASE_URL}/#{COVER_SIZE}/#{item[:url]}"
        else
          item[:thumb_url]
        end
      end
    end
  end
end
