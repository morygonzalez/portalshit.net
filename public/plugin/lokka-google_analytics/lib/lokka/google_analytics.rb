# frozen_string_literal: true

module Lokka
  module GoogleAnalytics
    def self.registered(app)
      app.get '/admin/plugins/google_analytics' do
        haml :"plugin/lokka-google_analytics/views/index", layout: :"admin/layout"
      end

      app.put '/admin/plugins/google_analytics' do
        Option.tracker = params['tracker']
        Option.tracker_ga4 = params['tracker_ga4']
        Option.tracker_dn = params['tracker_dn']
        flash[:notice] = 'Updated.'
        redirect to('/admin/plugins/google_analytics')
      end

      app.before do
        tracker = Option.tracker
        tracker_ga4 = Option.tracker_ga4
        if tracker_ga4.present? && Lokka.production? && !logged_in?
          content_for :header do
            ga4_tracking_code
          end
        end
      end
    end
  end

  module Helpers
    def ga4_tracking_code
      <<-JAVASCRIPT.strip_heredoc.html_safe
        <!-- Global site tag (gtag.js) - Google Analytics -->
        <script async src="https://www.googletagmanager.com/gtag/js?id=#{Option.tracker_ga4}"></script>
        <script>
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', '#{Option.tracker_ga4}');
        </script>
      JAVASCRIPT
    end
  end
end
