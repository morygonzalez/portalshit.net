require 'kramdown'

module Lokka
  module Markdown
    module Helpers
      def body_html(str)
        return Kramdown::Document.new(str).to_html
      end
    end
  end
end
