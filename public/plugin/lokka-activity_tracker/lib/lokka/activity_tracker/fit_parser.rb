# frozen_string_literal: true

require 'rubyfit'
require 'time'

module Lokka
  module ActivityTracker
    class UnsupportedFileError < StandardError; end

    # Callback handler for rubyfit parser
    class FitCallbackHandler
      attr_reader :records, :sessions, :laps, :file_id, :device_info

      def initialize
        @records = []
        @sessions = []
        @laps = []
        @file_id = nil
        @device_info = nil
      end

      def on_file_id(msg)
        @file_id = msg
      end

      def on_device_info(msg)
        @device_info ||= msg
      end

      def on_session(msg)
        @sessions << msg
      end

      def on_lap(msg)
        @laps << msg
      end

      def on_record(msg)
        @records << msg
      end

      def on_activity(msg)
        # Activity-level data
      end

      def on_event(msg)
        # Event data
      end

      def on_user_profile(msg)
        # User profile data
      end

      def on_weight_scale_info(msg)
        # Weight scale data
      end

      def print_msg(msg)
        # Suppress output
      end
    end

    class FitParser
      attr_reader :file_path, :handler

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
        @handler = nil
      end

      def parse
        raw_data = File.binread(file_path)
        @handler = FitCallbackHandler.new
        parser = RubyFit::FitParser.new(@handler)
        parser.parse(raw_data)
        self
      rescue StandardError => e
        raise UnsupportedFileError, "Failed to parse FIT file: #{e.message}"
      end

      def activity_summary
        return {} unless handler

        session = handler.sessions.first
        return {} unless session

        {
          activity_type: detect_activity_type(session),
          started_at: extract_timestamp(session),
          duration_seconds: extract_duration(session),
          total_distance_meters: safe_get(session, :total_distance),
          total_ascent_meters: safe_get(session, :total_ascent),
          avg_heart_rate: safe_get(session, :avg_heart_rate),
          max_heart_rate: safe_get(session, :max_heart_rate),
          avg_speed: safe_get(session, :avg_speed) || safe_get(session, :enhanced_avg_speed),
          avg_cadence: extract_avg_cadence(session),
          avg_power: safe_get(session, :avg_power)
        }.merge(extract_device_metadata)
      end

      def data_points
        return [] unless handler

        records = handler.records
        return [] if records.empty?

        start_time = extract_record_timestamp(records.first)

        records.map do |record|
          timestamp = extract_record_timestamp(record)
          elapsed = start_time && timestamp ? (timestamp - start_time).to_i : nil

          {
            elapsed_seconds: elapsed,
            latitude: safe_get(record, :position_lat) || safe_get(record, :y),
            longitude: safe_get(record, :position_long) || safe_get(record, :x),
            altitude_meters: safe_get(record, :altitude) || safe_get(record, :enhanced_altitude),
            heart_rate: safe_get(record, :heart_rate),
            speed: safe_get(record, :speed) || safe_get(record, :enhanced_speed),
            cadence: safe_get(record, :cadence),
            power: safe_get(record, :power),
            distance_meters: safe_get(record, :distance)
          }
        end
      end

      private

      def safe_get(hash_or_obj, key)
        return nil unless hash_or_obj

        if hash_or_obj.is_a?(Hash)
          hash_or_obj[key] || hash_or_obj[key.to_s]
        elsif hash_or_obj.respond_to?(key)
          hash_or_obj.send(key)
        elsif hash_or_obj.respond_to?(:[])
          hash_or_obj[key] || hash_or_obj[key.to_s]
        end
      rescue StandardError
        nil
      end

      def detect_activity_type(session)
        sport = safe_get(session, :sport)&.to_s&.downcase
        sub_sport = safe_get(session, :sub_sport)&.to_s&.downcase

        ACTIVITY_TYPE_MAP[sub_sport] || ACTIVITY_TYPE_MAP[sport] || 'other'
      end

      def extract_timestamp(session)
        timestamp = safe_get(session, :start_time) || safe_get(session, :timestamp)
        parse_timestamp(timestamp)
      end

      def extract_record_timestamp(record)
        timestamp = safe_get(record, :timestamp)
        parse_timestamp(timestamp)
      end

      def parse_timestamp(value)
        return nil unless value

        case value
        when Time, DateTime
          value
        when Integer, Float
          # FIT timestamps are seconds since Dec 31, 1989 00:00:00 UTC
          fit_epoch = Time.utc(1989, 12, 31, 0, 0, 0)
          fit_epoch + value
        when String
          Time.parse(value)
        else
          value.respond_to?(:to_time) ? value.to_time : nil
        end
      rescue StandardError
        nil
      end

      def extract_duration(session)
        timer_time = safe_get(session, :total_timer_time)
        elapsed_time = safe_get(session, :total_elapsed_time)

        (timer_time || elapsed_time)&.to_i
      end

      def extract_avg_cadence(session)
        safe_get(session, :avg_cadence) || safe_get(session, :avg_running_cadence)
      end

      def extract_device_metadata
        file_id = handler.file_id
        device_info = handler.device_info

        manufacturer = safe_get(file_id, :manufacturer)&.to_s
        product = safe_get(file_id, :product) || safe_get(file_id, :garmin_product)
        device_name = safe_get(device_info, :product_name) || safe_get(device_info, :device_name)

        {
          device_name: device_name ? humanize_device(device_name) : nil,
          device_manufacturer: manufacturer ? humanize_device(manufacturer) : nil,
          device_product_id: normalize_product_id(product)
        }
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
    end
  end
end
