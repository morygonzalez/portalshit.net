# frozen_string_literal: true

require 'openai'
require 'net/http'
require 'json'

module Lokka
  module ActivityTracker
    class TitleGenerator
      MODEL = 'gpt-5-mini'
      JST_OFFSET = 9 * 3600 # 9 hours in seconds

      PROMPT = <<~PROMPT
        以下のアクティビティ情報から、ブログ記事のタイトルとして使える日本語のタイトルを生成してください。

        ## 条件
        1. タイトルは20文字以内にしてください
        2. アクティビティの種類、距離、時間帯、場所などを考慮してください
        3. 自然な日本語で、運動記録として適切なタイトルにしてください
        4. 「ランニング」「サイクリング」などのアクティビティ名は必ず含めてください
        5. 距離がある場合は km 単位で含めてください（小数点以下1桁）
        6. 場所の情報がある場合は、地名やランドマーク名を含めると良いです
        7. 朝・昼・夜などの時間帯を含めると良いですが、場所を優先してください
        8. レスポンスは JSON フォーマットで、以下のような形式にしてください

        ```json
        {
          "title": "生成されたタイトル"
        }
        ```

        ## アクティビティ情報

        - 種類: %s
        - 開始日時: %s（日本時間）
        - 距離: %s km
        - 時間: %s
        - 平均ペース: %s
        - 獲得標高: %s m
        - 場所: %s
      PROMPT

      ACTIVITY_TYPE_JA = {
        'running' => 'ランニング',
        'trail_running' => 'トレイルランニング',
        'cycling' => 'サイクリング',
        'swimming' => '水泳',
        'walking' => 'ウォーキング',
        'hiking' => 'ハイキング',
        'other' => 'アクティビティ'
      }.freeze

      def initialize(summary, data_points = [])
        @summary = summary
        @data_points = data_points
        @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
        @location_name = nil
      end

      def generate
        return fallback_title unless ENV['OPENAI_API_KEY'].present?

        # Fetch location name from GPS coordinates
        @location_name = fetch_location_name

        response = @client.responses.create(
          parameters: {
            model: MODEL,
            input: build_prompt,
            reasoning: { effort: 'minimal' }
          }
        )
        result = JSON.parse(response.dig('output', 1, 'content', 0, 'text').strip)
        result['title'].presence || fallback_title
      rescue StandardError => e
        warn "[activity_tracker] Title generation failed: #{e.message}"
        fallback_title
      end

      private

      def build_prompt
        PROMPT % [
          activity_type_ja,
          formatted_datetime,
          formatted_distance,
          formatted_duration,
          formatted_pace,
          formatted_elevation,
          @location_name || '不明'
        ]
      end

      def activity_type_ja
        ACTIVITY_TYPE_JA[@summary[:activity_type]] || 'アクティビティ'
      end

      def started_at_jst
        return nil unless @summary[:started_at]

        time = @summary[:started_at]
        # Convert to JST if the time appears to be in UTC
        # FIT files typically store timestamps in UTC
        if time.utc? || time.zone.nil? || time.zone == 'UTC'
          time + JST_OFFSET
        else
          time
        end
      end

      def formatted_datetime
        jst_time = started_at_jst
        return '不明' unless jst_time

        jst_time.strftime('%Y年%m月%d日 %H:%M')
      end

      def formatted_distance
        return '不明' unless @summary[:total_distance_meters]

        (@summary[:total_distance_meters] / 1000.0).round(2)
      end

      def formatted_duration
        return '不明' unless @summary[:duration_seconds]

        seconds = @summary[:duration_seconds]
        hours = seconds / 3600
        minutes = (seconds % 3600) / 60
        secs = seconds % 60

        if hours > 0
          format('%d時間%02d分%02d秒', hours, minutes, secs)
        else
          format('%d分%02d秒', minutes, secs)
        end
      end

      def formatted_pace
        return '不明' unless @summary[:avg_speed] && @summary[:avg_speed] > 0

        # speed is in m/s, convert to min/km
        pace_seconds = 1000.0 / @summary[:avg_speed]
        pace_minutes = (pace_seconds / 60).to_i
        pace_secs = (pace_seconds % 60).to_i
        format("%d'%02d\"/km", pace_minutes, pace_secs)
      end

      def formatted_elevation
        return '不明' unless @summary[:total_ascent_meters]

        @summary[:total_ascent_meters].round
      end

      def fetch_location_name
        # Find a valid GPS coordinate from data points
        coord = find_valid_coordinate
        return nil unless coord

        reverse_geocode(coord[:latitude], coord[:longitude])
      rescue StandardError => e
        warn "[activity_tracker] Geocoding failed: #{e.message}"
        nil
      end

      def find_valid_coordinate
        return nil if @data_points.empty?

        # Try to get a coordinate from early in the activity (after GPS stabilizes)
        # Skip first few points as GPS may not be accurate yet
        candidates = @data_points.select do |dp|
          dp[:latitude] && dp[:longitude] &&
            dp[:latitude] != 0 && dp[:longitude] != 0
        end

        return nil if candidates.empty?

        # Get a point from about 10% into the activity for stable GPS
        index = [candidates.length / 10, 5].max
        index = [index, candidates.length - 1].min
        candidates[index]
      end

      def reverse_geocode(lat, lon)
        # Use OpenStreetMap Nominatim API for reverse geocoding
        uri = URI("https://nominatim.openstreetmap.org/reverse")
        uri.query = URI.encode_www_form(
          lat: lat,
          lon: lon,
          format: 'json',
          'accept-language' => 'ja',
          zoom: 14 # City/town level
        )

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 5

        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = 'LokkaActivityTracker/1.0'

        response = http.request(request)
        return nil unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)
        extract_location_name(data)
      end

      def extract_location_name(data)
        address = data['address']
        return data['display_name']&.split(',')&.first unless address

        # Priority: landmark > neighbourhood > suburb > city_district > city > town > village
        name_keys = %w[
          tourism amenity leisure
          neighbourhood suburb quarter
          city_district city town village
          county state
        ]

        location_parts = []

        # Get the most specific location name
        name_keys.each do |key|
          if address[key]
            location_parts << address[key]
            break if location_parts.length >= 1
          end
        end

        # Add city/ward info if available
        city_part = address['city'] || address['town'] || address['village']
        ward_part = address['city_district'] || address['suburb']

        if ward_part && city_part && ward_part != location_parts.first
          location_parts << "#{city_part}#{ward_part}"
        elsif city_part && city_part != location_parts.first
          location_parts << city_part
        end

        location_parts.uniq.first(2).join('・')
      end

      def fallback_title
        parts = []

        # Add location if available
        if @location_name
          # Extract short location name
          short_location = @location_name.split('・').first&.split(',')&.first
          parts << short_location if short_location
        elsif started_at_jst
          parts << time_of_day
        end

        parts << activity_type_ja

        if @summary[:total_distance_meters]
          distance_km = (@summary[:total_distance_meters] / 1000.0).round(1)
          parts << "#{distance_km}km"
        end

        parts.compact.join(' ')
      end

      def time_of_day
        jst_time = started_at_jst
        return nil unless jst_time

        hour = jst_time.hour
        case hour
        when 5..10
          '朝の'
        when 11..14
          '昼の'
        when 15..17
          '夕方の'
        when 18..20
          '夜の'
        else
          '深夜の'
        end
      end
    end
  end
end
