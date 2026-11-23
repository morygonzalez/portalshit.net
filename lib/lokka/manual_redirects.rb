# frozen_string_literal: true

require 'json'

module Lokka
  module ManualRedirects
    OPTION_NAME = 'manual_redirects'
    MAX_BYTES = 65_535

    def self.load
      value = Option.find_by(name: OPTION_NAME)&.value
      return {} if value.blank?

      rules = JSON.parse(value)
      return {} unless rules.is_a?(Hash) && rules.all? { |from, to| valid_path?(from) && valid_path?(to) }
      return {} if cyclic?(rules)

      rules
    rescue JSON::ParserError
      {}
    end

    def self.valid_path?(path)
      path.is_a?(String) && %r{\A/(?:[A-Za-z0-9._~-]+/)*[A-Za-z0-9._~-]*\z}.match?(path) &&
        path.split('/').none? { |segment| segment == '.' || segment == '..' }
    end

    def self.cyclic?(rules)
      checked = {}
      rules.each_key do |path|
        visited = {}
        while (destination = next_path(path, rules)) && !checked[path]
          return true if visited[path]

          visited[path] = true
          path = destination
        end
        checked.merge!(visited)
      end
      false
    end

    def self.next_path(path, rules)
      # The existing permalink fallback can strip a trailing slash.
      rules[path] || (path.delete_suffix('/') if path != '/' && path.end_with?('/'))
    end
    private_class_method :next_path
  end
end
