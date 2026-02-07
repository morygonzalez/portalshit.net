# frozen_string_literal: true

class AddFileHashToActivities < ActiveRecord::Migration[4.2]
  def change
    add_column :activities, :file_hash, :string
    add_index :activities, :file_hash, unique: true
  end
end
