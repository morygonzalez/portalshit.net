require 'kramdown'

module Lokka
  module Markdown
    def self.registered(app)
      app.before do
        @post = Post.new
      end
    end
  end

  module Helpers
    def markdown(str=nil)
      Kramdown::Document.new(str).to_html
    end
  end
end
