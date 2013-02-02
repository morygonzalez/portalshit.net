require 'pygments.rb'

module Lokka
  module Pygmentize
    def self.registered(app)
      app.before do
        assets_path = "/plugin/lokka-pygmentize/assets"

        content_for :header do
          text = <<-EOS.strip_heredoc
          <link href="#{assets_path}/monokai.css" rel="stylesheet" type="text/css" />
          EOS
        end
      end
    end
  end
end

class Entry
  def body
    doc  = Nokogiri::HTML(self.long_body)
    doc.search("//pre").each do |pre|
      code = pre.css("code")[0]
      pre.replace Pygments.highlight(
        code.text.rstrip,
        :lexer   => code[:class],
        :options => { :encoding => 'utf-8' }
      )
    end
    doc.to_s
  end
end
