# frozen_string_literal: true

module Lokka
  module ActivityTracker
    class StatisticsCalculator
      attr_reader :data_points

      def initialize(data_points)
        @data_points = data_points
      end

      def calculate
        {
          avg_heart_rate: calculate_avg(:heart_rate),
          max_heart_rate: calculate_max(:heart_rate),
          avg_speed: calculate_avg(:speed),
          max_speed: calculate_max(:speed),
          avg_cadence: calculate_avg(:cadence),
          avg_power: calculate_avg(:power),
          max_power: calculate_max(:power),
          total_distance_meters: calculate_total_distance,
          total_ascent_meters: calculate_total_ascent,
          duration_seconds: calculate_duration
        }
      end

      def calculate_avg(field)
        values = data_points.map { |dp| dp[field] || dp[field.to_s] }.compact
        return nil if values.empty?

        (values.sum.to_f / values.size).round(2)
      end

      def calculate_max(field)
        values = data_points.map { |dp| dp[field] || dp[field.to_s] }.compact
        return nil if values.empty?

        values.max
      end

      def calculate_total_distance
        distances = data_points.map { |dp| dp[:distance_meters] || dp['distance_meters'] }.compact
        return nil if distances.empty?

        distances.max
      end

      def calculate_total_ascent
        elevations = data_points.map { |dp| dp[:altitude_meters] || dp['altitude_meters'] }.compact
        return nil if elevations.size < 2

        total_ascent = 0.0
        elevations.each_cons(2) do |prev, curr|
          total_ascent += (curr - prev) if curr > prev
        end

        total_ascent.round(2)
      end

      def calculate_duration
        elapsed_times = data_points.map { |dp| dp[:elapsed_seconds] || dp['elapsed_seconds'] }.compact
        return nil if elapsed_times.empty?

        elapsed_times.max
      end

      def heart_rate_zones(max_hr = nil)
        return nil unless max_hr

        hr_values = data_points.map { |dp| dp[:heart_rate] || dp['heart_rate'] }.compact
        return nil if hr_values.empty?

        zones = {
          zone1: (0.5 * max_hr)..(0.6 * max_hr),   # Recovery
          zone2: (0.6 * max_hr)..(0.7 * max_hr),   # Endurance
          zone3: (0.7 * max_hr)..(0.8 * max_hr),   # Tempo
          zone4: (0.8 * max_hr)..(0.9 * max_hr),   # Threshold
          zone5: (0.9 * max_hr)..(max_hr)          # VO2max
        }

        zone_counts = zones.transform_values { 0 }

        hr_values.each do |hr|
          zones.each do |zone_name, range|
            zone_counts[zone_name] += 1 if range.cover?(hr)
          end
        end

        total = hr_values.size.to_f
        zones.transform_values { |_| 0 }.merge(
          zone_counts.transform_values { |count| (count / total * 100).round(1) }
        )
      end

      def pace_per_km
        points_with_data = data_points.select do |dp|
          (dp[:distance_meters] || dp['distance_meters']) &&
            (dp[:elapsed_seconds] || dp['elapsed_seconds'])
        end
        return [] if points_with_data.size < 2

        paces = []
        current_km = 1
        prev_point = points_with_data.first

        points_with_data.each do |point|
          distance = (point[:distance_meters] || point['distance_meters']).to_f
          if distance >= current_km * 1000
            elapsed = (point[:elapsed_seconds] || point['elapsed_seconds']).to_i
            prev_elapsed = (prev_point[:elapsed_seconds] || prev_point['elapsed_seconds']).to_i
            prev_distance = (prev_point[:distance_meters] || prev_point['distance_meters']).to_f

            km_time = elapsed - prev_elapsed
            km_distance = distance - prev_distance

            pace_per_km_seconds = (km_time / km_distance * 1000).round if km_distance > 0

            paces << {
              km: current_km,
              pace_seconds: pace_per_km_seconds,
              elapsed_seconds: elapsed
            }

            current_km += 1
            prev_point = point
          end
        end

        # Add final partial split if remaining distance is significant
        last_point = points_with_data.last
        last_distance = (last_point[:distance_meters] || last_point['distance_meters']).to_f
        last_elapsed = (last_point[:elapsed_seconds] || last_point['elapsed_seconds']).to_i
        prev_distance = (prev_point[:distance_meters] || prev_point['distance_meters']).to_f
        prev_elapsed = (prev_point[:elapsed_seconds] || prev_point['elapsed_seconds']).to_i
        remaining = last_distance - prev_distance

        if remaining >= 100
          km_time = last_elapsed - prev_elapsed
          pace_per_km_seconds = (km_time / remaining * 1000).round if remaining > 0
          fraction = (remaining / 1000.0).round(2)

          paces << {
            km: current_km,
            pace_seconds: pace_per_km_seconds,
            elapsed_seconds: last_elapsed,
            fraction: fraction
          }
        end

        paces
      end
    end
  end
end
