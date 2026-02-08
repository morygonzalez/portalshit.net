# frozen_string_literal: true

module Lokka
  module ActivityTracker
    class ActivityDataPoint < ActiveRecord::Base
      belongs_to :activity

      validates :activity, presence: true

      scope :with_gps, -> { where.not(latitude: nil, longitude: nil) }
      scope :with_heart_rate, -> { where.not(heart_rate: nil) }
      scope :ordered, -> { order(:elapsed_seconds) }

      def to_json_for_chart
        {
          elapsed_seconds: elapsed_seconds,
          latitude: latitude&.to_f,
          longitude: longitude&.to_f,
          altitude_meters: altitude_meters&.to_f,
          heart_rate: heart_rate,
          speed: speed&.to_f,
          cadence: cadence,
          power: power,
          distance_meters: distance_meters&.to_f
        }
      end

      def coordinates
        return nil unless latitude && longitude

        [latitude.to_f, longitude.to_f]
      end
    end
  end
end
