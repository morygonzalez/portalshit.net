# frozen_string_literal: true

module Lokka
  module RedirectResources
    def self.registered(app)
      app.get '/resources/:filename' do |filename|
        site_url = 'http://resources.portalshit.net'
        redirect "#{site_url}/#{filename}", 301
      end
    end
  end
end
