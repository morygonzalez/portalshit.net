# frozen_string_literal: true

require_relative 'activity_tracker/activity'
require_relative 'activity_tracker/activity_data_point'
require_relative 'activity_tracker/fit_parser'
require_relative 'activity_tracker/gpx_parser'
require_relative 'activity_tracker/statistics_calculator'
require_relative 'activity_tracker/shortcode_processor'

module Lokka
  module ActivityTracker
    def self.registered(app)
      # JSON API route (must be defined before :id route)
      app.get '/activities/:id.json' do |id|
        activity = Activity.find_by(id: id)
        halt 404, { error: 'Activity not found' }.to_json unless activity

        content_type :json
        cache_control :public, :must_revalidate, max_age: 5.minutes
        activity.to_json_for_chart.to_json
      end

      # Public routes
      app.get '/activities' do
        @activities = Activity.recent.page(params[:page]).per(20)
        @title = "#{I18n.t('activity_tracker.title', default: 'Activities')} - #{@site.title}"
        @bread_crumbs = [{ name: t('home'), link: '/' }]
        @bread_crumbs << { name: t('activity_tracker.title', default: 'Activities'), link: '/activities' }
        haml :"plugin/lokka-activity_tracker/views/index", layout: :"theme/#{@theme.name}/layout"
      end

      app.get '/activities/:id' do |id|
        @activity = Activity.find_by(id: id)
        halt 404, 'Activity not found' unless @activity

        @title = "#{@activity.title} - #{@site.title}"
        @bread_crumbs = [{ name: t('home'), link: '/' }]
        @bread_crumbs << { name: t('activity_tracker.title', default: 'Activities'), link: '/activities' }
        @bread_crumbs << { name: @activity.title, link: "/activities/#{@activity.id}" }
        haml :"plugin/lokka-activity_tracker/views/show", layout: :"theme/#{@theme.name}/layout"
      end

      # Admin routes
      app.get '/admin/activities' do
        login_required
        @activities = Activity.recent.page(params[:page]).per(20)
        @title = "#{I18n.t('activity_tracker.admin.title', default: 'Manage Activities')} - #{@site.title}"
        haml :"plugin/lokka-activity_tracker/views/admin/index", layout: :"admin/layout"
      end

      app.get '/admin/activities/new' do
        login_required
        @activity = Activity.new
        @title = "#{I18n.t('activity_tracker.admin.new', default: 'New Activity')} - #{@site.title}"
        haml :"plugin/lokka-activity_tracker/views/admin/new", layout: :"admin/layout"
      end

      app.post '/admin/activities' do
        login_required
        content_type :json

        file = params[:file]
        halt 400, { error: 'No file provided' }.to_json unless file

        tempfile = file[:tempfile]
        filename = file[:filename]
        format = detect_format(filename)

        halt 400, { error: 'Unsupported file format' }.to_json unless format

        begin
          parser = create_parser(format, tempfile.path)
          parser.parse

          summary = parser.activity_summary
          data_points = parser.data_points

          activity = Activity.new(
            user: current_user,
            title: params[:title].presence || filename,
            activity_type: summary[:activity_type],
            started_at: summary[:started_at],
            duration_seconds: summary[:duration_seconds],
            total_distance_meters: summary[:total_distance_meters],
            total_ascent_meters: summary[:total_ascent_meters],
            avg_heart_rate: summary[:avg_heart_rate],
            max_heart_rate: summary[:max_heart_rate],
            avg_speed: summary[:avg_speed],
            avg_cadence: summary[:avg_cadence],
            avg_power: summary[:avg_power],
            original_filename: filename,
            file_format: format
          )

          # Handle file upload to S3 if configured
          if Option.s3_bucket_name.present?
            upload_result = upload_to_s3(tempfile, filename)
            activity.file_url = upload_result[:url] if upload_result[:status] == 201
          end

          Activity.transaction do
            activity.save!

            data_points.each do |dp|
              activity.data_points.create!(
                elapsed_seconds: dp[:elapsed_seconds],
                latitude: dp[:latitude],
                longitude: dp[:longitude],
                altitude_meters: dp[:altitude_meters],
                heart_rate: dp[:heart_rate],
                speed: dp[:speed],
                cadence: dp[:cadence],
                power: dp[:power],
                distance_meters: dp[:distance_meters]
              )
            end
          end

          {
            success: true,
            activity_id: activity.id,
            redirect_url: "/activities/#{activity.id}"
          }.to_json
        rescue StandardError => e
          halt 500, { error: e.message }.to_json
        end
      end

      app.get '/admin/activities/:id/edit' do |id|
        login_required
        @activity = Activity.find_by(id: id)
        halt 404, 'Activity not found' unless @activity

        @title = "#{I18n.t('activity_tracker.admin.edit', default: 'Edit Activity')} - #{@site.title}"
        haml :"plugin/lokka-activity_tracker/views/admin/edit", layout: :"admin/layout"
      end

      app.put '/admin/activities/:id' do |id|
        login_required
        content_type :json

        activity = Activity.find_by(id: id)
        halt 404, { error: 'Activity not found' }.to_json unless activity

        if activity.update(
          title: params[:title],
          activity_type: params[:activity_type],
          entry_id: params[:entry_id].presence
        )
          { success: true, activity_id: activity.id }.to_json
        else
          halt 400, { error: activity.errors.full_messages.join(', ') }.to_json
        end
      end

      app.delete '/admin/activities/:id' do |id|
        login_required
        content_type :json

        activity = Activity.find_by(id: id)
        halt 404, { error: 'Activity not found' }.to_json unless activity

        if activity.destroy
          { success: true }.to_json
        else
          halt 500, { error: 'Failed to delete activity' }.to_json
        end
      end
    end
  end

  module Helpers
    def activity_tracker_assets_path
      '/plugin/lokka-activity_tracker/assets'
    end

    def activity_tracker_manifest
      @activity_tracker_manifest ||= begin
        file_path = File.join(Lokka.root, 'public', activity_tracker_assets_path, 'manifest.json')
        return {} unless File.exist?(file_path)

        content = File.read(file_path)
        JSON.parse(content)
      end
    end

    def activity_tracker_javascript_path(file_name)
      if Lokka.production?
        "#{activity_tracker_assets_path}/#{activity_tracker_manifest[file_name]}"
      else
        "plugin/lokka-activity_tracker/build/#{file_name}"
      end
    end

    def detect_format(filename)
      ext = File.extname(filename).downcase
      case ext
      when '.fit' then 'fit'
      when '.gpx' then 'gpx'
      end
    end

    def create_parser(format, file_path)
      case format
      when 'fit'
        ActivityTracker::FitParser.new(file_path)
      when 'gpx'
        ActivityTracker::GpxParser.new(file_path)
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end
    end

    def upload_to_s3(tempfile, filename)
      handler = Lokka::FileUploadHandler.new(
        { file: { tempfile: tempfile, filename: filename } },
        request.scheme
      )
      handler.handle
    end

    def render_activity_embed(activity_id)
      activity = ActivityTracker::Activity.find_by(id: activity_id)
      return '' unless activity

      %(<div class="activity-embed" data-activity-id="#{activity.id}"></div>)
    end

    def activity_tracker_assets_tag
      <<~HTML
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
        <script src="#{asset_path(activity_tracker_javascript_path('index.js'))}"></script>
      HTML
    end
  end
end

# Entry body shortcode processing - only process if shortcode is present
class Entry
  if method_defined?(:body)
    alias _original_activity_tracker_body body
    def activity_tracker_processed_body
      original = _original_activity_tracker_body
      return original unless original.is_a?(String)
      return original unless original.valid_encoding?
      return original unless original.include?('[activity:')

      Lokka::ActivityTracker::ShortcodeProcessor.new(original).process
    rescue StandardError
      long_body rescue raw_body
    end
    alias body activity_tracker_processed_body
  end

  if method_defined?(:short_body)
    alias _original_activity_tracker_short_body short_body
    def activity_tracker_processed_short_body
      original = _original_activity_tracker_short_body
      return original unless original.is_a?(String)
      return original unless original.valid_encoding?
      return original unless original.include?('[activity:')

      Lokka::ActivityTracker::ShortcodeProcessor.new(original).process
    rescue StandardError
      long_body rescue raw_body
    end
    alias short_body activity_tracker_processed_short_body
  end
end
