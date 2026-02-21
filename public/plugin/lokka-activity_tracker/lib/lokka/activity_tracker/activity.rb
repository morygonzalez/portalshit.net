# frozen_string_literal: true

require 'yaml'

module Lokka
  module ActivityTracker
    class Activity < ActiveRecord::Base
      belongs_to :user
      has_many :data_points, class_name: 'ActivityDataPoint', dependent: :destroy

      ACTIVITY_TYPES = %w[running trail_running cycling swimming walking hiking other].freeze
      ACTIVITY_TYPE_GROUPS = { 'all_running' => %w[running trail_running] }.freeze

      def self.resolve_type_filter(type)
        ACTIVITY_TYPE_GROUPS[type] || type
      end

      validates :title, presence: true
      validates :user, presence: true
      validates :activity_type, inclusion: { in: ACTIVITY_TYPES }, allow_nil: true
      validates :file_format, inclusion: { in: %w[fit gpx] }, allow_nil: true
      validates :file_hash, uniqueness: { message: :duplicate_file }, allow_nil: true

      scope :recent, -> { order(started_at: :desc) }
      scope :by_type, ->(type) { where(activity_type: type) }
      scope :in_month, ->(year, month) {
        start_date = Date.new(year, month, 1)
        end_date = start_date.end_of_month
        where(started_at: start_date.beginning_of_day..end_date.end_of_day)
      }
      scope :in_year, ->(year) {
        start_date = Date.new(year, 1, 1)
        end_date = Date.new(year, 12, 31)
        where(started_at: start_date.beginning_of_day..end_date.end_of_day)
      }
      scope :in_recent_months, ->(months) {
        cutoff = (months - 1).months.ago.beginning_of_month
        where('started_at >= ?', cutoff)
      }
      scope :search, ->(query) {
        return all if query.blank?
        where('title LIKE :q OR activity_type LIKE :q', q: "%#{query}%")
      }

      def self.available_activity_types
        distinct.pluck(:activity_type).compact
      end

      def self.available_years
        where.not(started_at: nil)
             .select('DISTINCT YEAR(started_at) as year')
             .order('year DESC')
             .map { |r| r['year'] || r.year }
             .compact
      end

      def self.monthly_stats(months_back = 6, activity_type: nil)
        stats = []
        today = Date.today

        (0...months_back).each do |i|
          date = today - i.months
          year = date.year
          month = date.month
          activities = in_month(year, month)
          activities = activities.by_type(activity_type) if activity_type.present?

          total_distance = activities.sum(:total_distance_meters) || 0
          total_duration = activities.sum(:duration_seconds) || 0
          total_ascent = activities.sum(:total_ascent_meters) || 0
          count = activities.count

          stats << {
            year: year,
            month: month,
            label: date.strftime('%Y-%m'),
            total_distance_km: (total_distance / 1000.0).round(2),
            total_ascent_meters: total_ascent,
            total_duration_seconds: total_duration,
            formatted_duration: format_duration_static(total_duration),
            count: count
          }
        end

        stats
      end

      def self.yearly_stats(year, activity_type: nil)
        stats = []

        (1..12).each do |month|
          date = Date.new(year, month, 1)
          activities = in_month(year, month)
          activities = activities.by_type(activity_type) if activity_type.present?

          total_distance = activities.sum(:total_distance_meters) || 0
          total_duration = activities.sum(:duration_seconds) || 0
          total_ascent = activities.sum(:total_ascent_meters) || 0
          count = activities.count

          stats << {
            year: year,
            month: month,
            label: date.strftime('%Y-%m'),
            total_distance_km: (total_distance / 1000.0).round(2),
            total_ascent_meters: total_ascent,
            total_duration_seconds: total_duration,
            formatted_duration: format_duration_static(total_duration),
            count: count
          }
        end

        stats
      end

      def self.group_by_month(activities)
        grouped = activities.group_by { |activity| activity.started_at&.beginning_of_month }
        months = grouped.keys.compact.sort.reverse
        months << nil if grouped.key?(nil)
        {
          grouped: grouped,
          months: months
        }
      end

      def self.monthly_summary(activities)
        total_distance_meters = activities.sum { |activity| activity.total_distance_meters.to_f }
        total_duration_seconds = activities.sum { |activity| activity.duration_seconds.to_i }
        total_ascent_meters = activities.sum { |activity| activity.total_ascent_meters.to_f }

        formatted_total_distance = total_distance_meters.positive? ? format('%.2f km', total_distance_meters / 1000.0) : '-'
        formatted_total_duration = format_duration_static(total_duration_seconds)
        formatted_total_ascent = total_ascent_meters.positive? ? "#{total_ascent_meters.round} m" : '-'

        {
          count: activities.size,
          formatted_total_distance: formatted_total_distance,
          formatted_total_duration: formatted_total_duration,
          formatted_total_ascent: formatted_total_ascent
        }
      end

      def self.format_duration_static(seconds)
        return '-' unless seconds && seconds > 0

        hours = seconds / 3600
        minutes = (seconds % 3600) / 60
        if hours > 0
          format('%<h>dh %<m>02dm', h: hours, m: minutes)
        else
          format('%<m>dm', m: minutes)
        end
      end

      def formatted_duration
        return nil unless duration_seconds

        hours = duration_seconds / 3600
        minutes = (duration_seconds % 3600) / 60
        seconds = duration_seconds % 60

        if hours > 0
          format('%<h>d:%<m>02d:%<s>02d', h: hours, m: minutes, s: seconds)
        else
          format('%<m>d:%<s>02d', m: minutes, s: seconds)
        end
      end

      def formatted_distance
        return nil unless total_distance_meters

        km = total_distance_meters / 1000.0
        format('%.2f km', km)
      end

      def localized_activity_type
        return nil unless activity_type

        I18n.t("activity_tracker.activity_types.#{activity_type}", default: activity_type.tr('_', ' ').capitalize)
      end

      def formatted_pace
        speed = effective_avg_speed
        return nil unless speed && speed > 0

        format_pace_from_speed(speed)
      end

      def calculated_avg_speed
        speeds = data_points.where.not(speed: nil).pluck(:speed)
        return nil if speeds.empty?

        speeds.sum / speeds.size
      end

      def effective_avg_speed
        return avg_speed if avg_speed && avg_speed > 0

        # Calculate from distance and duration if avg_speed is not stored
        return nil unless total_distance_meters && duration_seconds
        return nil unless total_distance_meters > 0 && duration_seconds > 0

        total_distance_meters / duration_seconds.to_f
      end

      def formatted_best_pace
        max_speed = data_points.maximum(:speed)
        return nil unless max_speed && max_speed > 0

        format_pace_from_speed(max_speed)
      end

      def device_auto_name
        mapped = self.class.device_name_from_map(device_manufacturer, device_product_id)
        return mapped if mapped

        parts = []
        parts << humanize_device(device_manufacturer) if device_manufacturer
        parts << device_product_id.to_s if device_product_id
        return nil if parts.empty?

        parts.join(' ')
      end

      def device_display_label
        return device_display_name if device_display_name && !device_display_name.strip.empty?

        device_auto_name
      end

      def self.device_name_from_map(manufacturer, product_id)
        return nil if manufacturer.nil? || product_id.nil?

        map = device_name_map
        return nil if map.empty?

        key = manufacturer.to_s.strip.downcase
        return nil if key.empty?

        manufacturer_map = map[key]
        return nil unless manufacturer_map.is_a?(Hash)

        manufacturer_map[product_id.to_s]
      end

      def self.device_name_map
        return @device_name_map if defined?(@device_name_map)

        map_path = File.join(Lokka.root, 'config', 'fit_device_map.yml')
        @device_name_map = if File.exist?(map_path)
                             raw = YAML.safe_load(File.read(map_path)) || {}
                             normalize_device_map(raw)
                           else
                             {}
                           end
      end

      def self.normalize_device_map(raw)
        raw.each_with_object({}) do |(manufacturer, products), acc|
          next unless manufacturer
          next unless products.is_a?(Hash)

          acc[manufacturer.to_s.strip.downcase] = products.transform_keys(&:to_s)
        end
      end

      def self.filtered_locations
        return @filtered_locations if defined?(@filtered_locations)

        config_path = File.join(Lokka.root, 'config', 'filtered_locations.yml')
        @filtered_locations = if File.exist?(config_path)
                                raw = YAML.safe_load(File.read(config_path), permitted_classes: [Symbol]) || []
                                raw.select { |loc| loc.is_a?(Hash) }.map do |loc|
                                  lat = loc['latitude']&.to_f
                                  lng = loc['longitude']&.to_f
                                  next nil unless lat && lng && lat != 0 && lng != 0

                                  { latitude: lat, longitude: lng, radius: (loc['radius'] || 300).to_f }
                                end.compact
                              else
                                # Fallback to ENV vars for backwards compatibility
                                lat = ENV['ACTIVITY_TRACKER_HOME_LAT']&.to_f
                                lng = ENV['ACTIVITY_TRACKER_HOME_LNG']&.to_f
                                radius = (ENV['ACTIVITY_TRACKER_HOME_RADIUS'] || 300).to_f
                                if lat && lng && lat != 0 && lng != 0
                                  [{ latitude: lat, longitude: lng, radius: radius }]
                                else
                                  []
                                end
                              end
      end

      def humanize_device(value)
        str = value.to_s.strip
        return nil if str.empty?

        str.tr('_', ' ').split.map { |part| part[0] ? part[0].upcase + part[1..].to_s : part }.join(' ')
      end

      private

      def format_pace_from_speed(speed)
        pace_seconds = 1000.0 / speed
        minutes = (pace_seconds / 60).to_i
        seconds = (pace_seconds % 60).to_i
        format("%d'%02d\" /km", minutes, seconds)
      end

      public

      def to_json_for_chart
        all_points = data_points.order(:elapsed_seconds).map(&:to_json_for_chart)

        # Use all points for statistics calculation (splits need full data)
        calculator = StatisticsCalculator.new(all_points)

        # Downsample for chart/map display if activity is long
        points = downsample_points(all_points)

        # Filter map points to hide private locations (within configured radius)
        map_points = filter_private_locations(points)

        {
          id: id,
          file_hash: file_hash,
          title: title,
          activity_type: activity_type,
          started_at: started_at&.iso8601,
          duration_seconds: duration_seconds,
          total_distance_meters: total_distance_meters&.to_f,
          total_ascent_meters: total_ascent_meters&.to_f,
          avg_heart_rate: avg_heart_rate,
          max_heart_rate: max_heart_rate,
          avg_speed: effective_avg_speed&.to_f,
          avg_cadence: avg_cadence,
          avg_power: avg_power,
          data_points: points,
          map_points: map_points,
          splits: calculator.pace_per_km
        }
      end

      # Downsample data points for long activities to improve rendering performance
      # - Activities under 50km: no downsampling
      # - Activities 50km+: target ~2000 points (roughly 40 points per km)
      def downsample_points(points)
        return points if points.length <= 2000

        distance_km = (total_distance_meters || 0) / 1000.0
        return points if distance_km <= 20

        # Target ~2000 points for smooth rendering
        target_count = 2000
        step = (points.length.to_f / target_count).ceil

        result = []
        points.each_with_index do |point, index|
          result << point if (index % step).zero?
        end

        # Always include last point for accurate endpoint
        result << points.last unless result.empty? || result.last == points.last

        result
      end

      def filter_private_locations(points)
        locations = self.class.filtered_locations
        return points if locations.empty?

        points.reject do |point|
          lat = point[:latitude]
          lng = point[:longitude]
          next false unless lat && lng

          locations.any? do |loc|
            haversine_distance(lat, lng, loc[:latitude], loc[:longitude]) <= loc[:radius]
          end
        end
      end

      def haversine_distance(lat1, lng1, lat2, lng2)
        r = 6371000 # Earth's radius in meters

        lat1_rad = lat1 * Math::PI / 180
        lat2_rad = lat2 * Math::PI / 180
        delta_lat = (lat2 - lat1) * Math::PI / 180
        delta_lng = (lng2 - lng1) * Math::PI / 180

        a = Math.sin(delta_lat / 2)**2 +
            Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(delta_lng / 2)**2
        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

        r * c
      end
    end
  end
end
