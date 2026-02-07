# frozen_string_literal: true

require 'openai'

module Lokka
  module ActivityTracker
    class TitleGenerator
      MODEL = 'gpt-5-mini'

      PROMPT = <<~PROMPT
        以下のアクティビティ情報から、ブログ記事のタイトルとして使える日本語のタイトルを生成してください。

        ## 条件
        1. タイトルは20文字以内にしてください
        2. アクティビティの種類、距離、時間帯などを考慮してください
        3. 自然な日本語で、運動記録として適切なタイトルにしてください
        4. 「ランニング」「サイクリング」などのアクティビティ名は必ず含めてください
        5. 距離がある場合は km 単位で含めてください（小数点以下1桁）
        6. 朝・昼・夜などの時間帯を含めると良いです
        7. レスポンスは JSON フォーマットで、以下のような形式にしてください

        ```json
        {
          "title": "生成されたタイトル"
        }
        ```

        ## アクティビティ情報

        - 種類: %s
        - 開始日時: %s
        - 距離: %s km
        - 時間: %s
        - 平均ペース: %s
        - 獲得標高: %s m
      PROMPT

      ACTIVITY_TYPE_JA = {
        'running' => 'ランニング',
        'cycling' => 'サイクリング',
        'swimming' => '水泳',
        'walking' => 'ウォーキング',
        'hiking' => 'ハイキング',
        'other' => 'アクティビティ'
      }.freeze

      def initialize(summary)
        @summary = summary
        @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
      end

      def generate
        return fallback_title unless ENV['OPENAI_API_KEY'].present?

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
          formatted_elevation
        ]
      end

      def activity_type_ja
        ACTIVITY_TYPE_JA[@summary[:activity_type]] || 'アクティビティ'
      end

      def formatted_datetime
        return '不明' unless @summary[:started_at]

        @summary[:started_at].strftime('%Y年%m月%d日 %H:%M')
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

      def fallback_title
        parts = []
        parts << time_of_day if @summary[:started_at]
        parts << activity_type_ja

        if @summary[:total_distance_meters]
          distance_km = (@summary[:total_distance_meters] / 1000.0).round(1)
          parts << "#{distance_km}km"
        end

        parts.join(' ')
      end

      def time_of_day
        return nil unless @summary[:started_at]

        hour = @summary[:started_at].hour
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
