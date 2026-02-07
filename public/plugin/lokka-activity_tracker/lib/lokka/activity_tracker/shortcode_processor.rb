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

        i18n_payload = {
          loading: I18n.t('activity_tracker.js.loading', default: 'Loading...'),
          error_prefix: I18n.t('activity_tracker.js.error_prefix', default: 'Error: '),
          embed_view_full: I18n.t('activity_tracker.js.embed_view_full', default: 'View full activity →'),
          embed_load_failed: I18n.t('activity_tracker.js.embed_load_failed', default: 'Failed to load activity data'),
          metric_distance: I18n.t('activity_tracker.js.metric_distance', default: 'Distance'),
          metric_duration: I18n.t('activity_tracker.js.metric_duration', default: 'Duration'),
          metric_pace: I18n.t('activity_tracker.js.metric_pace', default: 'Pace'),
          metric_avg_hr: I18n.t('activity_tracker.js.metric_avg_hr', default: 'Avg HR'),
          metric_max_hr: I18n.t('activity_tracker.js.metric_max_hr', default: 'Max HR'),
          metric_elevation: I18n.t('activity_tracker.js.metric_elevation', default: 'Elevation'),
          metric_cadence: I18n.t('activity_tracker.js.metric_cadence', default: 'Cadence'),
          metric_power: I18n.t('activity_tracker.js.metric_power', default: 'Power'),
          metric_heart_rate: I18n.t('activity_tracker.js.metric_heart_rate', default: 'Heart Rate'),
          metric_show_label: I18n.t('activity_tracker.js.metric_show_label', default: 'Show:')
        }

        <<~HTML
          <div class="activity-embed" data-activity-id="#{activity.id}" data-i18n='#{ERB::Util.html_escape(i18n_payload.to_json)}'>
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
