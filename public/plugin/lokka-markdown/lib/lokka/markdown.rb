require 'kramdown'

module Lokka
  module Markdown
  end

  module Helpers
    def markdown(str=nil)
      html = Kramdown::Document.new(str).to_html
      html = prettify(html)
    end

    def prettify(html)
      html.gsub!(/<pre>/, "<pre class=\"prettyprint\">")
      return html
    end
  end
end
