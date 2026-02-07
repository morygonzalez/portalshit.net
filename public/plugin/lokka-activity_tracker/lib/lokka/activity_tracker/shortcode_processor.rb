# frozen_string_literal: true

module Lokka
  module ActivityTracker
    class ShortcodeProcessor
      ACTIVITY_SHORTCODE_PATTERN = /\[activity:(\d+)\]/

      attr_reader :content

      def initialize(content)
        @content = content || ''
      end

      def process
        return content unless content.is_a?(String)
        return content if content.empty?

        safe_content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        return content unless safe_content.match?(ACTIVITY_SHORTCODE_PATTERN)

        safe_content.gsub(ACTIVITY_SHORTCODE_PATTERN) do |_match|
          activity_id = ::Regexp.last_match(1)
          render_activity_embed(activity_id)
        end
      end

      private

      def render_activity_embed(activity_id)
        activity = Activity.find_by(id: activity_id)
        return "[Activity ##{activity_id} not found]" unless activity

        <<~HTML
          <div class="activity-embed" data-activity-id="#{activity.id}">
            <noscript>
              <div class="activity-embed-fallback">
                <h4><a href="/activities/#{activity.id}">#{ERB::Util.html_escape(activity.title)}</a></h4>
                <p>
                  #{activity.activity_type&.capitalize}
                  #{activity.formatted_distance ? "・#{activity.formatted_distance}" : ''}
                  #{activity.formatted_duration ? "・#{activity.formatted_duration}" : ''}
                </p>
              </div>
            </noscript>
          </div>
        HTML
      end
    end
  end
end
