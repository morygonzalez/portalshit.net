# frozen_string_literal: true

module Lokka
  module ActivityTracker
    class ShortcodeProcessor
      ACTIVITY_SHORTCODE_PATTERN = /\[activity:(\d+)\]/

      attr_reader :content

      def initialize(content)
        @content = content || ''
        @assets_included = false
      end

      def process
        return content unless content.is_a?(String)
        return content if content.empty?

        safe_content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        return content unless safe_content.match?(ACTIVITY_SHORTCODE_PATTERN)

        result = safe_content.gsub(ACTIVITY_SHORTCODE_PATTERN) do |_match|
          activity_id = ::Regexp.last_match(1)
          render_activity_embed(activity_id)
        end

        # Append assets loader script at the end if any embeds were rendered
        if @assets_included
          result + assets_loader_script
        else
          result
        end
      end

      private

      def render_activity_embed(activity_id)
        activity = Activity.find_by(id: activity_id)
        return "[Activity ##{activity_id} not found]" unless activity

        @assets_included = true

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

      def assets_loader_script
        # Determine the JavaScript path based on environment
        js_path = if Lokka.production?
                    manifest = load_manifest
                    hashed_name = manifest['index.js'] || 'index.js'
                    "/plugin/lokka-activity_tracker/assets/#{hashed_name}"
                  else
                    "/plugin/lokka-activity_tracker/build/index.js"
                  end

        <<~HTML
          <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
          <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
          <script>
            (function() {
              if (window.activityTrackerLoaded) return;
              window.activityTrackerLoaded = true;
              var script = document.createElement('script');
              script.src = '#{js_path}';
              script.async = true;
              document.body.appendChild(script);
            })();
          </script>
        HTML
      end

      def load_manifest
        file_path = File.join(Lokka.root, 'public', 'plugin', 'lokka-activity_tracker', 'assets', 'manifest.json')
        return {} unless File.exist?(file_path)

        JSON.parse(File.read(file_path))
      rescue JSON::ParserError
        {}
      end
    end
  end
end
