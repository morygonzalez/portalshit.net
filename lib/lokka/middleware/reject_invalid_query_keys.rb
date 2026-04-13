# frozen_string_literal: true

module Lokka
  module Middleware
    # Rejects requests whose query string contains parameter names that are
    # not valid Ruby identifiers. kaminari-sinatra feeds query params to
    # ActionView::Base, which assigns them as instance variables
    # (`instance_variable_set("@#{key}", value)`) and raises NameError for
    # keys like ` AND 1`. Such keys only appear in SQL-injection probes, so
    # we drop them at the edge with 400.
    class RejectInvalidQueryKeys
      VALID_KEY = /\A[A-Za-z_][A-Za-z0-9_]*\z/

      def initialize(app)
        @app = app
      end

      def call(env)
        query = env['QUERY_STRING']
        if query.is_a?(String) && !query.empty?
          params = Rack::Utils.parse_query(query) rescue nil
          if params.nil? || params.keys.any? { |k| !VALID_KEY.match?(k) }
            return [400, { 'Content-Type' => 'text/plain' }, ['Bad Request']]
          end
        end

        @app.call(env)
      end
    end
  end
end
