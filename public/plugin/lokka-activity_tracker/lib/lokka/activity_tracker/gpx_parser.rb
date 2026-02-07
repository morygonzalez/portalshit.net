# frozen_string_literal: true

require 'gpx'

module Lokka
  module ActivityTracker
    class GpxParser
      attr_reader :file_path, :gpx_data

      ACTIVITY_TYPE_MAP = {
        'running' => 'running',
        'cycling' => 'cycling',
        'swimming' => 'swimming',
        'walking' => 'walking',
        'hiking' => 'hiking',
        'biking' => 'cycling',
        'run' => 'running',
        'bike' => 'cycling',
        'walk' => 'walking',
        'hike' => 'hiking'
      }.freeze

      def initialize(file_path)
        @file_path = file_path
        @gpx_data = nil
      end

      def parse
        @gpx_data = GPX::GPXFile.new(gpx_file: file_path)
        self
      end

      def activity_summary
        return {} unless gpx_data

        {
          activity_type: detect_activity_type,
          started_at: extract_start_time,
          duration_seconds: extract_duration,
          total_distance_meters: gpx_data.distance * 1000, # GPX gem returns km
          total_ascent_meters: calculate_total_ascent,
          avg_heart_rate: calculate_avg_heart_rate,
          max_heart_rate: calculate_max_heart_rate,
          avg_speed: calculate_avg_speed,
          avg_cadence: nil,
          avg_power: nil,
          device_name: nil,
          device_manufacturer: nil,
          device_product_id: nil
        }
      end

      def data_points
        return [] unless gpx_data

        points = []
        start_time = extract_start_time

        gpx_data.tracks.each do |track|
          track.segments.each do |segment|
            segment.points.each do |point|
              elapsed = start_time && point.time ? (point.time - start_time).to_i : nil

              points << {
                elapsed_seconds: elapsed,
                latitude: point.lat,
                longitude: point.lon,
                altitude_meters: point.elevation,
                heart_rate: extract_extension(point, 'hr'),
                speed: extract_extension(point, 'speed'),
                cadence: extract_extension(point, 'cad'),
                power: extract_extension(point, 'power'),
                distance_meters: nil
              }
            end
          end
        end

        calculate_distances(points)
      end

      private

      def detect_activity_type
        return nil unless gpx_data

        type = gpx_data.tracks.first&.name&.downcase
        ACTIVITY_TYPE_MAP[type] || 'other'
      end

      def extract_start_time
        first_point = nil
        gpx_data.tracks.each do |track|
          track.segments.each do |segment|
            segment.points.each do |point|
              first_point ||= point
              break if first_point
            end
            break if first_point
          end
          break if first_point
        end
        first_point&.time
      end

      def extract_duration
        first_time = nil
        last_time = nil

        gpx_data.tracks.each do |track|
          track.segments.each do |segment|
            segment.points.each do |point|
              first_time ||= point.time
              last_time = point.time
            end
          end
        end

        return nil unless first_time && last_time

        (last_time - first_time).to_i
      end

      def calculate_total_ascent
        total_ascent = 0.0
        prev_elevation = nil

        gpx_data.tracks.each do |track|
          track.segments.each do |segment|
            segment.points.each do |point|
              if prev_elevation && point.elevation && point.elevation > prev_elevation
                total_ascent += (point.elevation - prev_elevation)
              end
              prev_elevation = point.elevation
            end
          end
        end

        total_ascent
      end

      def calculate_avg_heart_rate
        heart_rates = collect_extension_values('hr')
        return nil if heart_rates.empty?

        (heart_rates.sum.to_f / heart_rates.size).round
      end

      def calculate_max_heart_rate
        heart_rates = collect_extension_values('hr')
        return nil if heart_rates.empty?

        heart_rates.max
      end

      def calculate_avg_speed
        return nil unless gpx_data.distance && gpx_data.distance > 0

        duration = extract_duration
        return nil unless duration && duration > 0

        (gpx_data.distance * 1000) / duration.to_f
      end

      def collect_extension_values(key)
        values = []
        gpx_data.tracks.each do |track|
          track.segments.each do |segment|
            segment.points.each do |point|
              value = extract_extension(point, key)
              values << value if value
            end
          end
        end
        values
      end

      def extract_extension(point, key)
        return nil unless point.respond_to?(:extensions) && point.extensions

        value = point.extensions[key] || point.extensions["gpxtpx:#{key}"]
        value&.to_i
      end

      def calculate_distances(points)
        cumulative_distance = 0.0

        points.each_with_index do |point, index|
          if index == 0
            point[:distance_meters] = 0.0
          else
            prev_point = points[index - 1]
            if point[:latitude] && point[:longitude] && prev_point[:latitude] && prev_point[:longitude]
              distance = haversine_distance(
                prev_point[:latitude], prev_point[:longitude],
                point[:latitude], point[:longitude]
              )
              cumulative_distance += distance
            end
            point[:distance_meters] = cumulative_distance
          end
        end

        points
      end

      def haversine_distance(lat1, lon1, lat2, lon2)
        r = 6371000 # Earth radius in meters

        phi1 = lat1 * Math::PI / 180
        phi2 = lat2 * Math::PI / 180
        delta_phi = (lat2 - lat1) * Math::PI / 180
        delta_lambda = (lon2 - lon1) * Math::PI / 180

        a = Math.sin(delta_phi / 2)**2 +
            Math.cos(phi1) * Math.cos(phi2) * Math.sin(delta_lambda / 2)**2
        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

        r * c
      end
    end
  end
end
