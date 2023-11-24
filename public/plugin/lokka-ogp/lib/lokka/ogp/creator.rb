module Lokka::OGP
  class Creator
    require 'mini_magick'

    GRAVITY = 'Center'
    TEXT_POSITION = '0,0'
    FONT = File.expand_path(File.join(Lokka.root, 'public/plugin/lokka-ogp/assets/NotoSansJP-ExtraBold.ttf'))
    FONT_SIZE = 60
    INDENTION_COUNT = 15
    ROW_LIMIT = 3

    class << self
      def build(text:, image:)
        text = prepare_text(text: text)
        image = MiniMagick::Image.open(image)
        image.combine_options do |config|
          config.font FONT
          config.fill 'white'
          config.resize '1200x675'
          config.gravity GRAVITY
          config.pointsize FONT_SIZE
          config.draw "text #{TEXT_POSITION} '#{text}'"
        end
      end

      private

      def prepare_text(text:)
        text = text.to_s.scan(/.{1,#{INDENTION_COUNT}}/)[0...ROW_LIMIT].join("\n")
      end
    end
  end
end
