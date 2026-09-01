# frozen_string_literal: true

require 'lokka/exception_notifier_ses'

module Lokka
  module Middleware
    # Minimal replacement for `ExceptionNotification::Rack`.
    #
    # The `exception_notification` gem (4.x) depends on `actionmailer`, which
    # pins `rack` to the 2.x series and therefore cannot coexist with
    # Sinatra 4 / Rack 3. The only piece we actually use is a Rack middleware
    # that catches an exception, hands it to a notifier and re-raises it, so
    # that downstream error handling still runs. The notifier itself
    # (`ExceptionNotifier::SesNotifier`) is our own code.
    class ExceptionNotifier
      # Exceptions that are a normal part of request handling and not worth
      # sending a mail about.
      def self.ignored_exceptions
        [defined?(Sinatra::NotFound) && Sinatra::NotFound].select { |k| k }
      end

      def initialize(app, options = {})
        @app = app
        @notifier = ::ExceptionNotifier::SesNotifier.new(options.fetch(:ses, {}))
      end

      def call(env)
        @app.call(env)
      rescue StandardError => e
        @notifier.call(e, env: env) unless ignored?(e)
        raise
      end

      private

      def ignored?(exception)
        self.class.ignored_exceptions.any? { |klass| exception.is_a?(klass) }
      end
    end
  end
end
