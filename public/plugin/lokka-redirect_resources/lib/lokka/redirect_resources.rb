module Lokka
  module RedirectResources
    def self.registered(app)
      app.get %r|/resources/(.*?)$|i do
        site_url = "http://resources.portalshit.net"
        redirect "#{site_url}/#{$1}", 301
      end
    end
  end
end
