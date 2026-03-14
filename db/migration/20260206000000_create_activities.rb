# frozen_string_literal: true

class CreateActivities < ActiveRecord::Migration[4.2]
  def change
    table_options = connection.adapter_name =~ /Mysql/i ? { options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci' } : {}
    create_table :activities, **table_options do |t|
      t.references :entry, foreign_key: true, null: true
      t.references :user, foreign_key: true, null: false

      t.string   :title, null: false
      t.string   :activity_type
      t.datetime :started_at
      t.integer  :duration_seconds

      t.decimal  :total_distance_meters, precision: 10, scale: 2
      t.decimal  :total_ascent_meters, precision: 8, scale: 2
      t.integer  :avg_heart_rate
      t.integer  :max_heart_rate
      t.decimal  :avg_speed, precision: 6, scale: 2
      t.integer  :avg_cadence
      t.integer  :avg_power

      t.string   :original_filename
      t.string   :file_url
      t.string   :file_format

      t.timestamps
    end

    add_index :activities, :started_at
    add_index :activities, :activity_type
  end
end
