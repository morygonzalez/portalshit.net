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
        if tracker.present? && Lokka.production? && !logged_in?
          content_for :header do
            ua_tracking_code
          end
        end
        if tracker_ga4.present? && Lokka.production? && !logged_in?
          content_for :header do
            ga4_tracking_code
          end
        end
      end
    end
  end

  module Helpers
    def ua_tracking_code
      <<-JAVASCRIPT.strip_heredoc.html_safe
        <script>
          (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
          (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
          m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
          })(window,document,'script','https://www.google-analytics.com/analytics.js','ga');

          ga('create', '#{Option.tracker}', 'auto');
          ga('send', 'pageview');
        </script>
      JAVASCRIPT
    end

    def ga4_tracking_code
      <<-JAVASCRIPT.strip_heredoc
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
