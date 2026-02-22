require 'uri'
require 'json'
require 'open-uri'

module Lokka
  module PhotoGallery
    class Geocoder
      def self.reverse_geocode(latitude:, longitude:)
        url = "https://nominatim.openstreetmap.org/reverse?lat=#{latitude}&lon=#{longitude}&format=json&accept-language=ja"

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
    end
  end
end
