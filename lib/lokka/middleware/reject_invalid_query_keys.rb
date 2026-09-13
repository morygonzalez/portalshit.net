# frozen_string_literal: true

module Lokka
  module Middleware
    # Rejects requests whose query string or form body contains parameter names
    # that are not valid Ruby identifiers. kaminari-sinatra feeds query params
    # to ActionView::Base, which assigns them as instance variables
    # (`instance_variable_set("@#{key}", value)`) and raises NameError for
    # keys like ` AND 1`. Invalid byte sequences can also raise ArgumentError
    # when a later filter applies a UTF-8 regexp. Such keys only appear in
    # probes, so we drop them at the edge with 400.
    class RejectInvalidQueryKeys
      VALID_KEY = /\A[A-Za-z_][A-Za-z0-9_]*\z/
      STATIC_EXT = /\.(?:css|js|map|png|jpe?g|gif|svg|ico|webp|avif|woff2?|ttf|otf|eot)\z/i

      def initialize(app)
        @app = app
      end

      def call(env)
        request = Rack::Request.new(env)

        return bad_request if invalid_query?(env) || invalid_form?(request)

        @app.call(env)
      rescue Rack::QueryParser::ParamsTooDeepError,
             Rack::QueryParser::ParameterTypeError,
             Rack::QueryParser::InvalidParameterError,
             ArgumentError
        bad_request
      end

      private

      def invalid_query?(env)
        query = env['QUERY_STRING']
        path = env['PATH_INFO']

        query.is_a?(String) && !query.empty? && query.include?('=') &&
          !(path.is_a?(String) && STATIC_EXT.match?(path)) &&
          invalid_keys?(Rack::Utils.parse_query(query))
      end

      def invalid_form?(request)
        invalid_keys?(request.POST)
      end

      def invalid_keys?(params)
        !params.is_a?(Hash) || params.keys.any? { |key| !valid_key?(key) }
      end

      def valid_key?(key)
        key.is_a?(String) && key.valid_encoding? && key.ascii_only? && VALID_KEY.match?(key)
      end

      def bad_request
        [400, { 'Content-Type' => 'text/plain' }, ['Bad Request']]
      end
    end
  end
end
