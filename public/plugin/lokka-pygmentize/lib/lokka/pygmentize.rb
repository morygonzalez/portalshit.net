require 'pygments.rb'

module Lokka
  module Pygmentize
    def self.registered(app)
      app.post '/pygmentize' do
        Pygments.highlight(
          params['snippet'],
          :lexar => params['lexar'],
          :options => { :encoding => 'utf-8' }
        )
      end

      app.before do
        assets_path = "/plugin/lokka-pygmentize/assets"

        content_for :header do
          text = <<-EOS
          <link href="#{assets_path}/monokai.css" rel="stylesheet" type="text/css" />
          EOS
        end

        content_for :footer do
          text = <<-EOS
          <script src="#{assets_path}/pygmentize.js" type="text/javascript"></script>
          EOS
        end
      end
    end
  end
end
