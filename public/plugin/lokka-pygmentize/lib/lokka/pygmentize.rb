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
  alias_method :original_body, :body
  def highlighted_body
    syntax_highlight(self.original_body)
  end
  alias_method :body, :highlighted_body

  alias_method :original_short_body, :short_body
  def highlighted_short_body
    syntax_highlight(self.original_short_body)
  end
  alias_method :short_body, :highlighted_short_body

  def syntax_highlight(body)
    doc = Nokogiri::HTML.fragment(body)
    doc.css("pre").each do |pre|
      code  = pre.css("code")[0]
      lexer = if pre[:class].present?
                pre[:class]
              elsif code.present? && code[:class].present?
                code[:class]
              else
                nil
              end
      begin
        pre.replace Pygments.highlight(
          code.text.rstrip,
          :lexer   => lexer,
          :options => { :encoding => 'utf-8' }
        ) if code
      rescue MentosError
        next
      end
    end
    doc.to_s
  end
end
