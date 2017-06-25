require "rack/recaptcha"
require "dotenv/load"

module Lokka
  module Recaptcha
    def self.registered(app)
      app.use Rack::Recaptcha,
        public_key:  ENV['RECAPTCHA_PUBLIC_KEY'],
        private_key: ENV['RECAPTCHA_PRIVATE_KEY']

      app.helpers Rack::Recaptcha::Helpers

      app.before do
        return if request.request_method != 'POST'
        return if request.env['PATH_INFO'] =~ /^\/admin\//
        return unless Lokka.production?

        halt 402, "You need to pay money to accomplish this action." if !recaptcha_valid?
      end
    end
  end
end
