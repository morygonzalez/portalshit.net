# frozen_string_literal: true

class CreateEntrySummaries < ActiveRecord::Migration[6.0]
  def change
    create_table :entry_summaries, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci' do |t|
      t.integer :entry_id,     null: false
      t.text    :summary,      null: false
      t.string  :content_hash, null: false, limit: 64
      t.timestamps
    end
    add_index :entry_summaries, :entry_id, unique: true
    add_index :entry_summaries, :content_hash
  end
end
