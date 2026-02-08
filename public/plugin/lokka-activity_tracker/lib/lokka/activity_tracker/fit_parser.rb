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

      SPORT_ENUM_MAP = {
        1 => 'running',
        2 => 'cycling',
        5 => 'swimming',
        11 => 'walking',
        17 => 'hiking',
        21 => 'cycling' # e-biking
      }.freeze

      SUB_SPORT_ENUM_MAP = {
        1 => 'treadmill',
        3 => 'trail_running',
        5 => 'indoor_cycling',
        6 => 'indoor_cycling',
        17 => 'swimming',
        18 => 'open_water'
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

        activity_type = detect_activity_type(session)
        raw_cadence = extract_avg_cadence(session)
        # Running cadence in FIT files is per foot, double it for total steps per minute
        avg_cadence = running_activity?(activity_type) && raw_cadence ? raw_cadence * 2 : raw_cadence

        {
          activity_type: activity_type,
          started_at: extract_timestamp(session),
          duration_seconds: extract_duration(session),
          total_distance_meters: safe_get(session, 'total_distance'),
          total_ascent_meters: safe_get(session, 'total_ascent'),
          avg_heart_rate: safe_get(session, 'avg_heart_rate'),
          max_heart_rate: safe_get(session, 'max_heart_rate'),
          avg_speed: safe_get(session, 'avg_speed') || safe_get(session, 'enhanced_avg_speed'),
          avg_cadence: avg_cadence,
          avg_power: safe_get(session, 'avg_power')
        }.merge(extract_device_metadata)
      end

      def data_points
        return [] unless handler

        records = handler.records
        return [] if records.empty?

        session = handler.sessions.first
        activity_type = session ? detect_activity_type(session) : nil
        is_running = running_activity?(activity_type)

        start_time = extract_record_timestamp(records.first)

        records.map do |record|
          timestamp = extract_record_timestamp(record)
          elapsed = start_time && timestamp ? (timestamp - start_time).to_i : nil
          raw_cadence = safe_get(record, 'cadence')
          # Running cadence in FIT files is per foot, double it for total steps per minute
          cadence = is_running && raw_cadence ? raw_cadence * 2 : raw_cadence

          {
            elapsed_seconds: elapsed,
            latitude: safe_get(record, 'position_lat'),
            longitude: safe_get(record, 'position_long'),
            altitude_meters: safe_get(record, 'altitude') || safe_get(record, 'enhanced_altitude'),
            heart_rate: safe_get(record, 'heart_rate'),
            speed: safe_get(record, 'speed') || safe_get(record, 'enhanced_speed'),
            cadence: cadence,
            power: safe_get(record, 'power'),
            distance_meters: safe_get(record, 'distance')
          }
        end
      end

      private

      def safe_get(hash_or_obj, key)
        return nil unless hash_or_obj

        # rubyfit returns hashes with string keys
        str_key = key.to_s

        if hash_or_obj.is_a?(Hash)
          hash_or_obj[str_key] || hash_or_obj[key]
        elsif hash_or_obj.respond_to?(:[])
          hash_or_obj[str_key] || hash_or_obj[key]
        elsif hash_or_obj.respond_to?(key)
          hash_or_obj.send(key)
        end
      rescue StandardError
        nil
      end

      def detect_activity_type(session)
        sport = normalize_sport_value(safe_get(session, 'sport'))
        sub_sport = normalize_sub_sport_value(safe_get(session, 'sub_sport'))

        ACTIVITY_TYPE_MAP[sub_sport] || ACTIVITY_TYPE_MAP[sport] || 'other'
      end

      def extract_timestamp(session)
        timestamp = safe_get(session, 'start_time') || safe_get(session, 'timestamp')
        parse_timestamp(timestamp)
      end

      def extract_record_timestamp(record)
        timestamp = safe_get(record, 'timestamp')
        parse_timestamp(timestamp)
      end

      def parse_timestamp(value)
        return nil unless value

        case value
        when Time, DateTime
          value
        when Integer, Float
          # rubyfit already converts FIT timestamps to Unix timestamps
          # by adding GARMIN_TIME_OFFSET (631065600 seconds)
          Time.at(value).utc
        when String
          Time.parse(value)
        else
          value.respond_to?(:to_time) ? value.to_time : nil
        end
      rescue StandardError
        nil
      end

      def extract_duration(session)
        timer_time = safe_get(session, 'total_timer_time')
        elapsed_time = safe_get(session, 'total_elapsed_time')

        (timer_time || elapsed_time)&.to_i
      end

      def extract_avg_cadence(session)
        safe_get(session, 'avg_cadence') || safe_get(session, 'avg_running_cadence')
      end

      def running_activity?(activity_type)
        %w[running walking hiking].include?(activity_type)
      end

      def extract_device_metadata
        file_id = handler.file_id
        device_info = handler.device_info

        manufacturer = safe_get(file_id, 'manufacturer')&.to_s
        product = safe_get(file_id, 'product') || safe_get(file_id, 'garmin_product')
        device_name = safe_get(device_info, 'product_name') || safe_get(device_info, 'device_name')

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

      def normalize_sport_value(value)
        return nil if value.nil?

        if value.is_a?(Integer)
          SPORT_ENUM_MAP[value] || value.to_s
        else
          value.to_s.strip.downcase
        end
      end

      def normalize_sub_sport_value(value)
        return nil if value.nil?

        if value.is_a?(Integer)
          SUB_SPORT_ENUM_MAP[value] || value.to_s
        else
          value.to_s.strip.downcase
        end
      end
    end
  end
end
