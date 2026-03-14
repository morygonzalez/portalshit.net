# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lokka::ActivityTracker::StatisticsCalculator do
  def make_point(attrs = {})
    { heart_rate: nil, speed: nil, cadence: nil, power: nil,
      distance_meters: nil, altitude_meters: nil, elapsed_seconds: nil }.merge(attrs)
  end

  describe '#calculate_avg' do
    it 'returns the average of the given field' do
      points = [make_point(heart_rate: 120), make_point(heart_rate: 140), make_point(heart_rate: 160)]
      calc = described_class.new(points)
      expect(calc.calculate_avg(:heart_rate)).to eq(140.0)
    end

    it 'ignores nil values' do
      points = [make_point(heart_rate: 100), make_point(heart_rate: nil), make_point(heart_rate: 200)]
      calc = described_class.new(points)
      expect(calc.calculate_avg(:heart_rate)).to eq(150.0)
    end

    it 'returns nil for empty data' do
      calc = described_class.new([])
      expect(calc.calculate_avg(:heart_rate)).to be_nil
    end

    it 'returns nil when all values are nil' do
      points = [make_point(heart_rate: nil), make_point(heart_rate: nil)]
      calc = described_class.new(points)
      expect(calc.calculate_avg(:heart_rate)).to be_nil
    end

    it 'rounds to 2 decimal places' do
      points = [make_point(speed: 3.0), make_point(speed: 4.0), make_point(speed: 5.0)]
      calc = described_class.new(points)
      expect(calc.calculate_avg(:speed)).to eq(4.0)
    end

    it 'works with string keys' do
      points = [{ 'heart_rate' => 100 }, { 'heart_rate' => 200 }]
      calc = described_class.new(points)
      expect(calc.calculate_avg(:heart_rate)).to eq(150.0)
    end
  end

  describe '#calculate_max' do
    it 'returns the maximum value' do
      points = [make_point(heart_rate: 120), make_point(heart_rate: 180), make_point(heart_rate: 150)]
      calc = described_class.new(points)
      expect(calc.calculate_max(:heart_rate)).to eq(180)
    end

    it 'returns nil for empty data' do
      calc = described_class.new([])
      expect(calc.calculate_max(:heart_rate)).to be_nil
    end

    it 'ignores nil values' do
      points = [make_point(power: nil), make_point(power: 250), make_point(power: nil)]
      calc = described_class.new(points)
      expect(calc.calculate_max(:power)).to eq(250)
    end
  end

  describe '#calculate_total_distance' do
    it 'returns the maximum distance_meters (cumulative distance)' do
      points = [
        make_point(distance_meters: 0),
        make_point(distance_meters: 1000),
        make_point(distance_meters: 5000)
      ]
      calc = described_class.new(points)
      expect(calc.calculate_total_distance).to eq(5000)
    end

    it 'returns nil when no distance data' do
      points = [make_point, make_point]
      calc = described_class.new(points)
      expect(calc.calculate_total_distance).to be_nil
    end
  end

  describe '#calculate_total_ascent' do
    it 'sums only elevation gains' do
      points = [
        make_point(altitude_meters: 100),
        make_point(altitude_meters: 150),
        make_point(altitude_meters: 120),
        make_point(altitude_meters: 200)
      ]
      calc = described_class.new(points)
      # gain: 50 + 0 + 80 = 130
      expect(calc.calculate_total_ascent).to eq(130.0)
    end

    it 'returns 0 when only descending' do
      points = [
        make_point(altitude_meters: 200),
        make_point(altitude_meters: 150),
        make_point(altitude_meters: 100)
      ]
      calc = described_class.new(points)
      expect(calc.calculate_total_ascent).to eq(0.0)
    end

    it 'returns nil with fewer than 2 points' do
      points = [make_point(altitude_meters: 100)]
      calc = described_class.new(points)
      expect(calc.calculate_total_ascent).to be_nil
    end

    it 'returns nil with no altitude data' do
      points = [make_point, make_point, make_point]
      calc = described_class.new(points)
      expect(calc.calculate_total_ascent).to be_nil
    end
  end

  describe '#calculate_duration' do
    it 'returns the maximum elapsed_seconds' do
      points = [
        make_point(elapsed_seconds: 0),
        make_point(elapsed_seconds: 600),
        make_point(elapsed_seconds: 1800)
      ]
      calc = described_class.new(points)
      expect(calc.calculate_duration).to eq(1800)
    end

    it 'returns nil when no elapsed data' do
      calc = described_class.new([make_point])
      expect(calc.calculate_duration).to be_nil
    end
  end

  describe '#heart_rate_zones' do
    let(:points) do
      # max_hr = 200, zones: z1(100-120), z2(120-140), z3(140-160), z4(160-180), z5(180-200)
      [
        make_point(heart_rate: 110),  # zone1
        make_point(heart_rate: 130),  # zone2
        make_point(heart_rate: 150),  # zone3
        make_point(heart_rate: 170),  # zone4
        make_point(heart_rate: 190)   # zone5
      ]
    end
    let(:calc) { described_class.new(points) }

    it 'distributes HR values into 5 zones' do
      result = calc.heart_rate_zones(200)
      expect(result.keys).to match_array(%i[zone1 zone2 zone3 zone4 zone5])
      expect(result[:zone1]).to eq(20.0)
      expect(result[:zone2]).to eq(20.0)
      expect(result[:zone3]).to eq(20.0)
      expect(result[:zone4]).to eq(20.0)
      expect(result[:zone5]).to eq(20.0)
    end

    it 'returns nil when max_hr is nil' do
      expect(calc.heart_rate_zones(nil)).to be_nil
    end

    it 'returns nil when no HR data' do
      calc = described_class.new([make_point, make_point])
      expect(calc.heart_rate_zones(200)).to be_nil
    end

    it 'handles boundary values' do
      # HR exactly at zone boundary (120 = 0.6 * 200) belongs to both zone1 and zone2
      points = [make_point(heart_rate: 120)]
      calc = described_class.new(points)
      result = calc.heart_rate_zones(200)
      expect(result[:zone1]).to eq(100.0)
      expect(result[:zone2]).to eq(100.0)
    end
  end

  describe '#pace_per_km' do
    it 'calculates pace for each km split' do
      points = [
        make_point(distance_meters: 0, elapsed_seconds: 0),
        make_point(distance_meters: 500, elapsed_seconds: 150),
        make_point(distance_meters: 1000, elapsed_seconds: 300),
        make_point(distance_meters: 1500, elapsed_seconds: 450),
        make_point(distance_meters: 2000, elapsed_seconds: 600)
      ]
      calc = described_class.new(points)
      result = calc.pace_per_km

      expect(result.length).to eq(2)
      expect(result[0][:km]).to eq(1)
      expect(result[0][:pace_seconds]).to eq(300) # 300s for 1000m
      expect(result[1][:km]).to eq(2)
      expect(result[1][:pace_seconds]).to eq(300)
    end

    it 'includes final partial split when >= 100m remaining' do
      points = [
        make_point(distance_meters: 0, elapsed_seconds: 0),
        make_point(distance_meters: 1000, elapsed_seconds: 300),
        make_point(distance_meters: 1500, elapsed_seconds: 450)
      ]
      calc = described_class.new(points)
      result = calc.pace_per_km

      expect(result.length).to eq(2)
      expect(result[1][:fraction]).to eq(0.5)
    end

    it 'excludes final partial split when < 100m remaining' do
      points = [
        make_point(distance_meters: 0, elapsed_seconds: 0),
        make_point(distance_meters: 1000, elapsed_seconds: 300),
        make_point(distance_meters: 1050, elapsed_seconds: 315)
      ]
      calc = described_class.new(points)
      result = calc.pace_per_km

      expect(result.length).to eq(1)
    end

    it 'returns empty array with fewer than 2 points' do
      points = [make_point(distance_meters: 0, elapsed_seconds: 0)]
      calc = described_class.new(points)
      expect(calc.pace_per_km).to eq([])
    end

    it 'returns empty array with no distance/time data' do
      calc = described_class.new([make_point, make_point])
      expect(calc.pace_per_km).to eq([])
    end
  end

  describe '#calculate' do
    it 'returns a hash with all statistics' do
      points = [
        make_point(heart_rate: 120, speed: 3.0, cadence: 80, power: 200,
                   distance_meters: 0, altitude_meters: 100, elapsed_seconds: 0),
        make_point(heart_rate: 160, speed: 4.0, cadence: 90, power: 300,
                   distance_meters: 5000, altitude_meters: 200, elapsed_seconds: 1800)
      ]
      calc = described_class.new(points)
      result = calc.calculate

      expect(result[:avg_heart_rate]).to eq(140.0)
      expect(result[:max_heart_rate]).to eq(160)
      expect(result[:avg_speed]).to eq(3.5)
      expect(result[:max_speed]).to eq(4.0)
      expect(result[:avg_cadence]).to eq(85.0)
      expect(result[:avg_power]).to eq(250.0)
      expect(result[:max_power]).to eq(300)
      expect(result[:total_distance_meters]).to eq(5000)
      expect(result[:total_ascent_meters]).to eq(100.0)
      expect(result[:duration_seconds]).to eq(1800)
    end
  end
end
