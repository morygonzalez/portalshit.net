# frozen_string_literal: true

class CreateEntryTermFrequencies < ActiveRecord::Migration[4.2]
  def change
    create_table :entry_term_frequencies, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci' do |t|
      t.integer :entry_id, null: false
      t.string :term, null: false, limit: 255
      t.integer :term_count, null: false, default: 0
      t.datetime :entry_updated_at, null: false
    end
    add_index :entry_term_frequencies, [:entry_id, :term], unique: true
    add_index :entry_term_frequencies, :entry_id
  end
end
