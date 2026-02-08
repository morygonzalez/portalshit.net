# frozen_string_literal: true

class RemoveEntryIdFromActivities < ActiveRecord::Migration[4.2]
  def change
    remove_foreign_key :activities, :entries
    remove_reference :activities, :entry
  end
end
