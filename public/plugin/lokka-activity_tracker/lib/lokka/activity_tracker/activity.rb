# frozen_string_literal: true

module Lokka
  module ActivityTracker
    class Activity < ActiveRecord::Base
      belongs_to :entry, optional: true
      belongs_to :user
      has_many :data_points, class_name: 'ActivityDataPoint', dependent: :destroy

      ACTIVITY_TYPES = %w[running cycling swimming walking hiking other].freeze

      validates :title, presence: true
      validates :user, presence: true
      validates :activity_type, inclusion: { in: ACTIVITY_TYPES }, allow_nil: true
      validates :file_format, inclusion: { in: %w[fit gpx] }, allow_nil: true

      scope :recent, -> { order(started_at: :desc) }
      scope :by_type, ->(type) { where(activity_type: type) }
      scope :in_month, ->(year, month) {
        start_date = Date.new(year, month, 1)
        end_date = start_date.end_of_month
        where(started_at: start_date.beginning_of_day..end_date.end_of_day)
      }

      def self.monthly_stats(months_back = 6)
        stats = []
        today = Date.today

        (0...months_back).each do |i|
          date = today - i.months
          year = date.year
          month = date.month
          activities = in_month(year, month)

          total_distance = activities.sum(:total_distance_meters) || 0
          total_duration = activities.sum(:duration_seconds) || 0
          count = activities.count

          stats << {
            year: year,
            month: month,
            label: date.strftime('%Y-%m'),
            total_distance_km: (total_distance / 1000.0).round(2),
            total_duration_seconds: total_duration,
            formatted_duration: format_duration_static(total_duration),
            count: count
          }
        end

        stats
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

      def formatted_pace
        speed = avg_speed || calculated_avg_speed
        return nil unless speed && speed > 0

        format_pace_from_speed(speed)
      end

      def calculated_avg_speed
        speeds = data_points.where.not(speed: nil).pluck(:speed)
        return nil if speeds.empty?

        speeds.sum / speeds.size
      end

      def formatted_best_pace
        max_speed = data_points.maximum(:speed)
        return nil unless max_speed && max_speed > 0

        format_pace_from_speed(max_speed)
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
        points = data_points.order(:elapsed_seconds).map(&:to_json_for_chart)
        calculator = StatisticsCalculator.new(points)

        {
          id: id,
          title: title,
          activity_type: activity_type,
          started_at: started_at&.iso8601,
          duration_seconds: duration_seconds,
          total_distance_meters: total_distance_meters&.to_f,
          total_ascent_meters: total_ascent_meters&.to_f,
          avg_heart_rate: avg_heart_rate,
          max_heart_rate: max_heart_rate,
          avg_speed: avg_speed&.to_f,
          avg_cadence: avg_cadence,
          avg_power: avg_power,
          data_points: points,
          splits: calculator.pace_per_km
        }
      end
    end
  end
end
