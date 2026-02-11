# frozen_string_literal: true

require_relative 'activity_tracker/activity'
require_relative 'activity_tracker/activity_data_point'
require_relative 'activity_tracker/fit_parser'
require_relative 'activity_tracker/gpx_parser'
require_relative 'activity_tracker/statistics_calculator'
require_relative 'activity_tracker/shortcode_processor'
require_relative 'activity_tracker/title_generator'
require 'securerandom'
require 'digest'

module Lokka
  module ActivityTracker
    def self.registered(app)
      # Monthly stats JSON API
      app.get '/activities/monthly_stats.json' do
        content_type :json
        cache_control :public, :must_revalidate, max_age: 10.minutes

        activity_type = Activity.resolve_type_filter(params[:type])
        year = params[:year]&.to_i
        if year && year > 0
          Activity.yearly_stats(year, activity_type: activity_type).to_json
        else
          Activity.monthly_stats(12, activity_type: activity_type).to_json
        end
      end

      # JSON API route (must be defined before other parameterized routes)
      app.get '/activities/:file_hash.json' do |file_hash|
        activity = Activity.find_by(file_hash: file_hash)
        halt 404, { error: 'Activity not found' }.to_json unless activity

        content_type :json
        cache_control :public, :must_revalidate, max_age: 5.minutes
        activity.to_json_for_chart.to_json
      end

      # Public routes - index (recent 13 months)
      app.get '/activities' do
        @available_years = Activity.available_years
        @selected_year = nil
        @selected_type = params[:type]
        activities = Activity.recent.in_recent_months(13)
        activities = activities.by_type(Activity.resolve_type_filter(@selected_type)) if @selected_type.present?
        @activities = activities
        @title = "#{I18n.t('activity_tracker.title', default: 'Activities')} - #{@site.title}"
        @archive_mode = :recent

        @bread_crumbs = [{ name: t('home'), link: '/' }]
        @bread_crumbs << { name: t('activity_tracker.title', default: 'Activities'), link: '/activities' }
        haml :"plugin/lokka-activity_tracker/views/index", layout: :"theme/#{@theme.name}/layout"
      end

      # Combined route for year archive and activity detail
      # - 4-digit number (1900-2099): year archive
      # - Otherwise: file_hash for activity detail
      app.get '/activities/:param' do |param|
        if param.match?(/\A\d{4}\z/)
          # Year archive mode
          year = param.to_i
          halt 404, 'Invalid year' unless year >= 1900 && year <= 2099

          @available_years = Activity.available_years
          @selected_year = year
          @selected_type = params[:type]
          activities = Activity.recent.in_year(year)
          activities = activities.by_type(Activity.resolve_type_filter(@selected_type)) if @selected_type.present?
          @activities = activities
          @title = "#{I18n.t('activity_tracker.title', default: 'Activities')} #{year} - #{@site.title}"
          @archive_mode = :year

          @bread_crumbs = [{ name: t('home'), link: '/' }]
          @bread_crumbs << { name: t('activity_tracker.title', default: 'Activities'), link: '/activities' }
          @bread_crumbs << { name: year.to_s, link: "/activities/#{year}" }
          haml :"plugin/lokka-activity_tracker/views/index", layout: :"theme/#{@theme.name}/layout"
        else
          # Activity detail mode
          @activity = Activity.find_by(file_hash: param)
          halt 404, 'Activity not found' unless @activity

          @title = "#{@activity.title} - #{@site.title}"
          @bread_crumbs = [{ name: t('home'), link: '/' }]
          @bread_crumbs << { name: t('activity_tracker.title', default: 'Activities'), link: '/activities' }
          @bread_crumbs << { name: @activity.title, link: "/activities/#{@activity.file_hash}" }
          haml :"plugin/lokka-activity_tracker/views/show", layout: :"theme/#{@theme.name}/layout"
        end
      end

      app.get '/admin/plugins/activity_tracker' do
        redirect to('/admin/activities')
      end

      # Admin routes
      app.get '/admin/activities' do
        login_required
        @selected_type = params[:type]
        activities = Activity.recent
        activities = activities.by_type(Activity.resolve_type_filter(@selected_type)) if @selected_type.present?
        @activities = activities.page(params[:page]).per(100)
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
        filename = sanitize_filename(file[:filename])
        format = detect_format(filename)

        halt 400, { error: 'Unsupported file format' }.to_json unless format

        if format == 'zip'
          results = process_zip_file(tempfile, current_user)

          if results.empty?
            halt 400, { error: I18n.t('activity_tracker.zip_no_valid_files', default: 'No FIT or GPX files found in the ZIP archive') }.to_json
          end

          {
            success: results.any? { |r| r[:success] },
            results: results,
            redirect_url: '/admin/activities'
          }.to_json
        else
          result = process_single_file(tempfile, filename, current_user)

          if result[:success]
            {
              success: true,
              activity_id: result[:activity_id],
              redirect_url: '/admin/activities'
            }.to_json
          else
            status_code = result[:status] || 500
            halt status_code, { error: result[:error] }.to_json
          end
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

        payload = json_body

        if activity.update(payload)
          { success: true, activity_id: activity.id }.to_json
        else
          halt 400, { error: activity.errors.full_messages.join(', ') }.to_json
        end
      end

      app.delete '/admin/activities/:id' do |id|
        login_required
        activity = Activity.find_by(id: id)
        if request.preferred_type&.to_s == 'application/json'
          content_type :json
        end

        if activity.nil?
          if request.preferred_type&.to_s == 'application/json'
            halt 404, { error: 'Activity not found' }.to_json
          else
            halt 404, 'Activity not found'
          end
        end

        if activity.destroy
          if request.preferred_type&.to_s == 'application/json'
            { success: true }.to_json
          else
            redirect to('/admin/activities')
          end
        else
          if request.preferred_type&.to_s == 'application/json'
            halt 500, { error: 'Failed to delete activity' }.to_json
          else
            halt 500, 'Failed to delete activity'
          end
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

    def sanitize_filename(filename)
      return '' if filename.nil?

      # Handle encoding issues with Japanese filenames
      str = filename.to_s
      str = str.dup if str.frozen?

      # Try to encode to UTF-8, replacing invalid characters
      unless str.valid_encoding?
        str = str.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      end

      # Force UTF-8 encoding
      str.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    end

    def detect_format(filename)
      ext = File.extname(filename).downcase
      case ext
      when '.fit' then 'fit'
      when '.gpx' then 'gpx'
      when '.zip' then 'zip'
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

    def json_body
      raw = request.body.read
      raw = '{}' if raw.nil? || raw.strip.empty?
      JSON.parse(raw)
    rescue JSON::ParserError
      halt 400, { error: 'Invalid JSON' }.to_json
    end

    def process_single_file(tempfile, filename, user)
      format = detect_format(filename)
      return { success: false, error: 'Unsupported file format', status: 400 } unless format && format != 'zip'

      file_hash = Digest::SHA256.file(tempfile.path).hexdigest

      existing = ActivityTracker::Activity.find_by(file_hash: file_hash)
      if existing
        return {
          success: false,
          error: I18n.t('activity_tracker.duplicate_file', default: 'This file has already been uploaded'),
          status: 409
        }
      end

      parser = create_parser(format, tempfile.path)
      parser.parse

      summary = parser.activity_summary
      data_points = parser.data_points

      title = ActivityTracker::TitleGenerator.new(summary, data_points).generate rescue filename

      activity = ActivityTracker::Activity.new(
        user: user,
        title: title,
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
        device_manufacturer: summary[:device_manufacturer],
        device_product_id: summary[:device_product_id],
        original_filename: filename,
        file_format: format,
        file_hash: file_hash
      )

      if Option.s3_bucket_name.present?
        upload_result = upload_to_s3(tempfile, filename)
        activity.file_url = upload_result[:url] if upload_result[:status] == 201
      end

      ActivityTracker::Activity.transaction do
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

      { success: true, activity_id: activity.id }
    rescue ActivityTracker::UnsupportedFileError => e
      { success: false, error: I18n.t('activity_tracker.unsupported_file', default: e.message), status: 400 }
    rescue StandardError => e
      error_id = SecureRandom.hex(8)
      if respond_to?(:logger) && logger
        logger.error("[activity_tracker] upload failed error_id=#{error_id} #{e.class}: #{e.message}")
        logger.error(e.backtrace.join("\n")) if e.backtrace
      else
        warn("[activity_tracker] upload failed error_id=#{error_id} #{e.class}: #{e.message}")
      end
      { success: false, error: "Upload failed (Error ID: #{error_id})", status: 500 }
    end

    def process_zip_file(tempfile, user)
      require 'zip'
      results = []

      ::Zip::File.open(tempfile.path) do |zip|
        zip.each do |entry|
          next if entry.directory?
          next if entry.name.start_with?('__MACOSX')
          next if File.basename(entry.name).start_with?('.')

          entry_filename = sanitize_filename(File.basename(entry.name))
          entry_format = detect_format(entry_filename)
          next unless entry_format && entry_format != 'zip'

          Tempfile.open(['activity', ".#{entry_format}"]) do |tmp|
            tmp.binmode
            tmp.write(entry.get_input_stream.read)
            tmp.rewind

            result = process_single_file(tmp, entry_filename, user)
            results << result.merge(filename: entry_filename)

            sleep 1.5 if result[:success]
          end
        end
      end

      results
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
