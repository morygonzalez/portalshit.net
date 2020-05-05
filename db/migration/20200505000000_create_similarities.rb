# frozen_string_literal: true

class CreateSimilarities < ActiveRecord::Migration[4.2]
  def change
    create_table :similarities do |t|
      t.references :entry
      t.references :similar_entry
      t.integer :score
      t.index %i[entry_id similar_entry_id], unique: true
    end
  end
end
