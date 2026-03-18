# frozen_string_literal: true

module Lokka
  module Middleware
    class ForceUtf8
      def initialize(app)
        @app = app
      end

      def call(env)
        %w[PATH_INFO REQUEST_URI REQUEST_PATH QUERY_STRING].each do |key|
          next unless env[key].is_a?(String)

          env[key] = env[key].dup.force_encoding(Encoding::UTF_8)
          unless env[key].valid_encoding?
            env[key] = env[key].encode(Encoding::UTF_8, Encoding::ASCII_8BIT,
                                       invalid: :replace, undef: :replace, replace: '?')
          end
        end

        @app.call(env)
      end
    end
  end
end
