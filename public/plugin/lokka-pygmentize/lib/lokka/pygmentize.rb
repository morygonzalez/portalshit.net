require 'pygments.rb'

module Lokka
  module Pygmentize
    def self.registered(app)
      app.post '/pygmentize' do
        return false unless request.referer =~ /#{request.host}/
        Pygments.highlight(
          params['snippet'],
          :lexer => params['lexer'],
          :options => { :encoding => 'utf-8' }
        )
      end

      app.before do
        assets_path = "/plugin/lokka-pygmentize/assets"

        content_for :header do
          text = <<-EOS.strip_heredoc
          <link href="#{assets_path}/monokai.css" rel="stylesheet" type="text/css" />
          EOS
        end

        content_for :footer do
          text = <<-EOS.strip_heredoc
          <script src="#{assets_path}/pygmentize.js" type="text/javascript"></script>
          EOS
        end
      end
    end
  end
end
