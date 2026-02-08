# frozen_string_literal: true

class AddDeviceMetadataToActivities < ActiveRecord::Migration[4.2]
  def change
    add_column :activities, :device_manufacturer, :string
    add_column :activities, :device_product_id, :integer
    add_column :activities, :device_display_name, :string
  end
end
