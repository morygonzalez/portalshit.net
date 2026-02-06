# frozen_string_literal: true

class CreateActivityDataPoints < ActiveRecord::Migration[4.2]
  def change
    create_table :activity_data_points do |t|
      t.references :activity, foreign_key: true, null: false

      t.integer  :elapsed_seconds
      t.decimal  :latitude, precision: 10, scale: 7
      t.decimal  :longitude, precision: 10, scale: 7
      t.decimal  :altitude_meters, precision: 7, scale: 2
      t.integer  :heart_rate
      t.decimal  :speed, precision: 6, scale: 2
      t.integer  :cadence
      t.integer  :power
      t.decimal  :distance_meters, precision: 10, scale: 2
    end

    add_index :activity_data_points, [:activity_id, :elapsed_seconds]
  end
end
