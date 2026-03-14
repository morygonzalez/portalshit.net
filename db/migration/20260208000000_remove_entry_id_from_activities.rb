# frozen_string_literal: true

class RemoveEntryIdFromActivities < ActiveRecord::Migration[4.2]
  def change
    remove_foreign_key :activities, :entries if connection.adapter_name =~ /Mysql/i
    remove_reference :activities, :entry
  end
end
