# frozen_string_literal: true

require 'fit_parser'
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
        'hike' => 'hiking'
      }.freeze

      def initialize(file_path)
        @file_path = file_path
        @fit_data = nil
        @records = []
      end

      def parse
        @fit_data = ::FitParser.load_file(file_path)
        @records = @fit_data.records
          .select { |r| r.content.record_type != :definition }
          .map(&:content)
        self
      rescue RuntimeError => e
        if e.message.include?('No definition for local message type')
          raise UnsupportedFileError, 'This FIT file contains unsupported data format'
        end
        raise
      end

      def activity_summary
        return {} unless fit_data

        session = find_record_by_type(:session)
        activity = find_record_by_type(:activity)

        {
          activity_type: detect_activity_type(session),
          started_at: extract_timestamp(session),
          duration_seconds: extract_duration(session),
          total_distance_meters: safe_get(session, :total_distance),
          total_ascent_meters: safe_get(session, :total_ascent),
          avg_heart_rate: safe_get(session, :avg_heart_rate),
          max_heart_rate: safe_get(session, :max_heart_rate),
          avg_speed: safe_get(session, :enhanced_avg_speed) || safe_get(session, :avg_speed),
          avg_cadence: extract_avg_cadence(session),
          avg_power: safe_get(session, :avg_power)
        }.merge(extract_device_metadata)
      end

      def data_points
        return [] unless fit_data

        record_messages = @records.select { |r| record_type?(r, :record) }
        return [] if record_messages.empty?

        start_time = parse_timestamp(safe_get(record_messages.first, :timestamp))

        record_messages.map do |record|
          timestamp = parse_timestamp(safe_get(record, :timestamp))
          elapsed = start_time && timestamp ? (timestamp - start_time).to_i : nil

          {
            elapsed_seconds: elapsed,
            latitude: convert_semicircles_to_degrees(safe_get(record, :position_lat)),
            longitude: convert_semicircles_to_degrees(safe_get(record, :position_long)),
            altitude_meters: extract_altitude(record),
            heart_rate: safe_get(record, :heart_rate),
            speed: extract_speed(record),
            cadence: safe_get(record, :cadence),
            power: safe_get(record, :power),
            distance_meters: safe_get(record, :distance)
          }
        end
      end

      private

      def find_record_by_type(type)
        @records.find { |r| record_type?(r, type) }
      end

      def record_type?(record, type)
        return false unless record.respond_to?(:record_type)

        record.record_type == type
      end

      def safe_get(record, field)
        return nil unless record
        return nil unless record.respond_to?(field)

        record.send(field)
      rescue StandardError
        nil
      end

      def extract_device_metadata
        device_info = find_record_by_type(:device_info) || find_record_by_type(:file_id)
        return {} unless device_info

        name = safe_get(device_info, :device_name) ||
               safe_get(device_info, :product_name) ||
               safe_get(device_info, :name)
        manufacturer = safe_get(device_info, :manufacturer)
        product = safe_get(device_info, :product) || safe_get(device_info, :garmin_product)

        device_name = name ? humanize_device(name) : nil

        {
          device_name: device_name,
          device_manufacturer: normalize_device_value(manufacturer),
          device_product_id: normalize_product_id(product)
        }
      end

      def humanize_device(value)
        str = value.to_s.strip
        return '' if str.empty?

        str.tr('_', ' ').split.map { |part| part[0] ? part[0].upcase + part[1..].to_s : part }.join(' ')
      end

      def normalize_device_value(value)
        str = value.to_s.strip
        str.empty? ? nil : humanize_device(str)
      end

      def normalize_product_id(value)
        str = value.to_s.strip
        return nil unless str.match?(/\A\d+\z/)

        str.to_i
      end

      def detect_activity_type(session)
        return 'other' unless session

        sport = safe_get(session, :sport)&.to_s&.downcase
        ACTIVITY_TYPE_MAP[sport] || 'other'
      end

      def extract_timestamp(session)
        timestamp = safe_get(session, :start_time) || safe_get(session, :timestamp)
        parse_timestamp(timestamp)
      end

      def parse_timestamp(value)
        return nil unless value

        case value
        when Time, DateTime
          value
        when String
          Time.parse(value)
        when Numeric
          Time.at(value)
        else
          value.respond_to?(:to_time) ? value.to_time : nil
        end
      rescue ArgumentError
        nil
      end

      def extract_duration(session)
        return nil unless session

        timer_time = safe_get(session, :total_timer_time)
        elapsed_time = safe_get(session, :total_elapsed_time)

        (timer_time || elapsed_time)&.to_i
      end

      def extract_avg_cadence(session)
        return nil unless session

        safe_get(session, :avg_cadence) || safe_get(session, :avg_running_cadence)
      end

      def convert_semicircles_to_degrees(semicircles)
        return nil unless semicircles

        semicircles * (180.0 / 2**31)
      end

      def extract_speed(record)
        # Try different field names for speed
        safe_get(record, :enhanced_speed) ||
          safe_get(record, :speed) ||
          safe_get(record, :avg_speed)
      end

      def extract_altitude(record)
        # Try different field names for altitude
        safe_get(record, :enhanced_altitude) ||
          safe_get(record, :altitude) ||
          safe_get(record, :elevation)
      end
    end
  end
end
