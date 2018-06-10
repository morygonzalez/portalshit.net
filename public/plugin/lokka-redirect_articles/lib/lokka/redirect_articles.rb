# frozen_string_literal: true

module Lokka
  module RedirectArticles
    def self.registered(app)
      app.get %r{/article\.php} do
        unless request.query_string.empty?
          /id=(\d+)?/ =~ request.query_string
          redirect "/#{Regexp.last_match(1)}", 301
        end
      end

      app.get %r{/rss/(recent|2\.0)\.php} do
        redirect '/index.atom', 301
      end

      app.get %r{/index\.php} do
        redirect '/', 301
      end
    end
  end
end
