# frozen_string_literal: true

class AddSummaryToEntries < ActiveRecord::Migration[6.1]
  def change
    add_column :entries, :summary, :text
  end
end
