# frozen_string_literal: true

module Lokka
  module ActivityTracker
    class ShortcodeProcessor
      # Match both numeric ID and file_hash (64-char hex string)
      ACTIVITY_SHORTCODE_PATTERN = /\[activity:([a-f0-9]+)\]/i

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

      def render_activity_embed(identifier)
        # Try to find by file_hash first (64-char hex), then by numeric ID
        activity = if identifier.match?(/\A[a-f0-9]{64}\z/i)
                     Activity.find_by(file_hash: identifier)
                   else
                     Activity.find_by(id: identifier)
                   end
        return "[Activity ##{identifier} not found]" unless activity

        @assets_included = true

        i18n_payload = {
          loading: I18n.t('activity_tracker.js.loading', default: 'Loading...'),
          error_prefix: I18n.t('activity_tracker.js.error_prefix', default: 'Error: '),
          embed_view_full: I18n.t('activity_tracker.js.embed_view_full', default: 'View full activity →'),
          embed_load_failed: I18n.t('activity_tracker.js.embed_load_failed', default: 'Failed to load activity data'),
          metric_type: I18n.t('activity_tracker.js.metric_type', default: 'Type'),
          metric_distance: I18n.t('activity_tracker.js.metric_distance', default: 'Distance'),
          metric_duration: I18n.t('activity_tracker.js.metric_duration', default: 'Duration'),
          metric_pace: I18n.t('activity_tracker.js.metric_pace', default: 'Pace'),
          metric_avg_hr: I18n.t('activity_tracker.js.metric_avg_hr', default: 'Avg HR'),
          metric_max_hr: I18n.t('activity_tracker.js.metric_max_hr', default: 'Max HR'),
          metric_elevation: I18n.t('activity_tracker.js.metric_elevation', default: 'Elevation'),
          metric_cadence: I18n.t('activity_tracker.js.metric_cadence', default: 'Cadence'),
          metric_power: I18n.t('activity_tracker.js.metric_power', default: 'Power'),
          metric_heart_rate: I18n.t('activity_tracker.js.metric_heart_rate', default: 'Heart Rate'),
          metric_show_label: I18n.t('activity_tracker.js.metric_show_label', default: 'Show:'),
          activity_type_running: I18n.t('activity_tracker.js.activity_type_running', default: 'Running'),
          activity_type_trail_running: I18n.t('activity_tracker.js.activity_type_trail_running', default: 'Trail Running'),
          activity_type_cycling: I18n.t('activity_tracker.js.activity_type_cycling', default: 'Cycling'),
          activity_type_swimming: I18n.t('activity_tracker.js.activity_type_swimming', default: 'Swimming'),
          activity_type_walking: I18n.t('activity_tracker.js.activity_type_walking', default: 'Walking'),
          activity_type_hiking: I18n.t('activity_tracker.js.activity_type_hiking', default: 'Hiking'),
          activity_type_other: I18n.t('activity_tracker.js.activity_type_other', default: 'Other')
        }

        <<~HTML
          <div class="activity-embed" data-activity-hash="#{activity.file_hash}" data-i18n='#{ERB::Util.html_escape(i18n_payload.to_json)}'>
            <noscript>
              <div class="activity-embed-fallback">
                <h4><a href="/activities/#{activity.file_hash}">#{ERB::Util.html_escape(activity.title)}</a></h4>
                <p>
                  #{activity.localized_activity_type}
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
