module Lokka
  module RedirectArticles
    def self.registered(app)
      app.get %r{/article\.php} do
        unless request.query_string.empty?
          /id=(\d+)?/ =~ request.query_string
          redirect "/#{$1}", 301
        end
      end

      app.get %r{/rss/.+} do
        redirect "/index.atom", 301
      end
    end
  end
end
