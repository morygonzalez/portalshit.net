module Lokka::OGP
  class Creator
    require 'mini_magick'
    require 'natto'

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
          config.draw %(text #{TEXT_POSITION} "#{text}")
        end
      end

      private

      def nm
        @nm ||= Natto::MeCab.new(userdic: File.expand_path('lib/tokenizer/userdic.dic'))
      end

      def prepare_text(text:)
        splitted_text = nm.enum_parse(text).map(&:surface)
        row_length = 0
        result = []
        do_loop = true
        while do_loop do
          splitted_text.each.with_index(1) do |item, i|
            result[row_length] ||= ''
            if result[row_length].length > INDENTION_COUNT
              row_length += 1
              result[row_length] = ''
            end
            result[row_length] += item
            do_loop = false if splitted_text.length == i
          end
          do_loop = false if ROW_LIMIT - 1 > row_length
        end
        result.delete_if(&:blank?)
        if result[-1].length == 1
          result[-2] += result[-1]
          result.pop
        end
        result.join("\n")
      end
    end
  end
end
