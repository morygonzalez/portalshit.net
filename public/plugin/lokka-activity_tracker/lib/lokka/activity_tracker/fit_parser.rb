# frozen_string_literal: true

require 'fit4ruby'
require 'time'

module Lokka
  module ActivityTracker
    class UnsupportedFileError < StandardError; end

    class FitParser
      attr_reader :file_path, :fit_data

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
        'hike' => 'hiking',
        'trail_running' => 'running',
        'open_water' => 'swimming',
        'indoor_cycling' => 'cycling',
        'indoor_running' => 'running',
        'treadmill' => 'running'
      }.freeze

      def initialize(file_path)
        @file_path = file_path
        @fit_data = nil
      end

      def parse
        # Suppress fit4ruby warnings about unknown fields
        original_stderr = $stderr
        $stderr = StringIO.new

        begin
          @fit_data = Fit4Ruby.read(file_path)
        ensure
          $stderr = original_stderr
        end

        raise UnsupportedFileError, 'Failed to parse FIT file' unless @fit_data
        self
      rescue StandardError => e
        if e.is_a?(UnsupportedFileError)
          raise
        elsif e.message.include?('Abort') || e.message.include?('Error')
          raise UnsupportedFileError, 'This FIT file contains unsupported data format'
        end
        raise UnsupportedFileError, "Failed to parse FIT file: #{e.message}"
      end

      def activity_summary
        return {} unless fit_data

        session = fit_data.sessions&.first
        return {} unless session

        {
          activity_type: detect_activity_type(session),
          started_at: session.start_time,
          duration_seconds: extract_duration(session),
          total_distance_meters: session.total_distance,
          total_ascent_meters: session.total_ascent,
          avg_heart_rate: session.avg_heart_rate,
          max_heart_rate: session.max_heart_rate,
          avg_speed: session.enhanced_avg_speed || session.avg_speed,
          avg_cadence: extract_avg_cadence(session),
          avg_power: session.avg_power
        }.merge(extract_device_metadata)
      end

      def data_points
        return [] unless fit_data

        records = fit_data.records
        return [] if records.nil? || records.empty?

        start_time = records.first.timestamp

        records.map do |record|
          elapsed = start_time && record.timestamp ? (record.timestamp - start_time).to_i : nil

          {
            elapsed_seconds: elapsed,
            latitude: record.position_lat,
            longitude: record.position_long,
            altitude_meters: extract_altitude(record),
            heart_rate: record.heart_rate,
            speed: extract_speed(record),
            cadence: record.cadence,
            power: record.power,
            distance_meters: record.distance
          }
        end
      end

      private

      def detect_activity_type(session)
        sport = session.sport&.to_s&.downcase
        sub_sport = session.sub_sport&.to_s&.downcase

        ACTIVITY_TYPE_MAP[sub_sport] || ACTIVITY_TYPE_MAP[sport] || 'other'
      end

      def extract_duration(session)
        timer_time = session.total_timer_time
        elapsed_time = session.total_elapsed_time

        (timer_time || elapsed_time)&.to_i
      end

      def extract_avg_cadence(session)
        session.avg_cadence || session.avg_running_cadence
      rescue NoMethodError
        nil
      end

      def extract_device_metadata
        file_id = fit_data.file_id
        device_infos = fit_data.device_infos

        manufacturer = file_id&.manufacturer&.to_s
        product = file_id&.product

        # Try to get device name from device_infos
        device_name = nil
        if device_infos&.any?
          primary_device = device_infos.find { |d| d.device_index == 0 } || device_infos.first
          device_name = primary_device&.product_name
        end

        {
          device_name: device_name ? humanize_device(device_name) : nil,
          device_manufacturer: manufacturer ? humanize_device(manufacturer) : nil,
          device_product_id: normalize_product_id(product)
        }
      rescue NoMethodError
        {}
      end

      def humanize_device(value)
        str = value.to_s.strip
        return nil if str.empty?

        str.tr('_', ' ').split.map { |part| part[0] ? part[0].upcase + part[1..].to_s : part }.join(' ')
      end

      def normalize_product_id(value)
        return nil if value.nil?

        str = value.to_s.strip
        return nil unless str.match?(/\A\d+\z/)

        str.to_i
      end

      def extract_speed(record)
        record.enhanced_speed || record.speed
      rescue NoMethodError
        nil
      end

      def extract_altitude(record)
        record.enhanced_altitude || record.altitude
      rescue NoMethodError
        nil
      end
    end
  end
end
