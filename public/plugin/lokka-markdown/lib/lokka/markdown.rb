require 'kramdown'
require "rack/pygments"

Rack::Pygments.new(:html_tag => "highlight", :html_attr => "lang")

module Lokka
  module Markdown
  end

  module Helpers
    def markdown(str=nil)
      html = Kramdown::Document.new(str).to_html
      html = prettify(html)
      # pygmentize(html) 
    end

    def prettify(html)
      html.gsub!(/<pre>/, "<pre class=\"prettyprint\">")
      return html
    end

    def pygmentize(html)
      html.gsub!(/<pre>(.+?)<\/pre>/) { "<highlight>#{$1}</highlight>" }
      return html
    end
  end
end
