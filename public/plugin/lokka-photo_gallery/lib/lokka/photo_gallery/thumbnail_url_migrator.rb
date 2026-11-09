# frozen_string_literal: true

require_relative '../photo_gallery'

module Lokka
  module PhotoGallery
    # Rewrites the thumbnail URLs embedded in galleries created before the
    # thumbnail size was increased.  update_columns deliberately preserves the
    # published and updated timestamps of the entries.
    class ThumbnailUrlMigrator
      OLD_URL_PREFIX = "#{IMAGEPROXY_BASE_URL}/115/#{RESOURCE_BASE_URL}/".freeze
      NEW_URL_PREFIX = "#{IMAGEPROXY_BASE_URL}/#{THUMBNAIL_SIZE}/#{RESOURCE_BASE_URL}/".freeze

      def initialize(entries:)
        @entries = entries
      end

      def apply!
        updated_entries = 0

        Entry.transaction do
          @entries.each do |entry|
            original_body = entry.raw_body.to_s
            rewritten = original_body.gsub(OLD_URL_PREFIX, NEW_URL_PREFIX)
            next if rewritten == original_body

            entry.update_columns(body: rewritten)
            updated_entries += 1
          end
        end

        updated_entries
      end
    end
  end
end
