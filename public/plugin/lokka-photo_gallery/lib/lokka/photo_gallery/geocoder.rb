require 'uri'
require 'json'
require 'open-uri'

module Lokka
  module PhotoGallery
    class Geocoder
      # Nominatim の利用規約は「1 秒あたり 1 リクエストまで」。フォルダ一括処理では
      # 呼び出し側の sleep で間隔を空けていたが、管理画面からは 1 枚ごとに独立した
      # リクエストで届くため、ここで間隔を保証する。
      MIN_INTERVAL = 1.0

      @throttle_mutex = Mutex.new
      @last_requested_at = nil

      def self.reverse_geocode(latitude:, longitude:)
        url = "https://nominatim.openstreetmap.org/reverse?lat=#{latitude}&lon=#{longitude}&format=json&accept-language=ja"

        throttle
        response = URI.open(url, 'User-Agent' => 'portalshit.net/1.0 (morygonzalez@gmail.com)')
        data = JSON.parse(response.read).with_indifferent_access

        location = data['display_name'].split(', ')[0..-3].reverse[0..4].join
        licence_text, licence_url = parse_licence(data['licence'])

        {
          location: location,
          licence_text: licence_text,
          licence_url: licence_url,
          raw: data
        }
      rescue StandardError => e
        warn "Reverse geocoding failed for (#{latitude}, #{longitude}): #{e.message}"
        { location: nil, licence_text: nil, licence_url: nil, raw: { error: e.message } }
      end

      def self.parse_licence(licence_string)
        return [nil, nil] if licence_string.nil?

        *text_parts, url = licence_string.split("\s")
        [text_parts.join(' '), url]
      end

      def self.throttle
        wait = @throttle_mutex.synchronize do
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          elapsed = @last_requested_at ? now - @last_requested_at : MIN_INTERVAL
          seconds = [MIN_INTERVAL - elapsed, 0].max
          @last_requested_at = now + seconds
          seconds
        end

        sleep wait if wait > 0
      end
      private_class_method :throttle
    end
  end
end
