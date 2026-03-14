# frozen_string_literal: true

class CreateEntryEmbeddings < ActiveRecord::Migration[6.0]
  def up
    table_options = connection.adapter_name =~ /Mysql/i ? { options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci' } : {}
    create_table :entry_embeddings, **table_options do |t|
      t.integer  :entry_id,         null: false
      t.json     :embedding,        null: false
      t.string   :model,            null: false, default: 'text-embedding-3-small'
      t.integer  :token_count
      t.datetime :entry_updated_at, null: false
    end
    add_index :entry_embeddings, :entry_id, unique: true

    drop_table :entry_term_frequencies
  end

  def down
    drop_table :entry_embeddings

    table_options = connection.adapter_name =~ /Mysql/i ? { options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci' } : {}
    create_table :entry_term_frequencies, **table_options do |t|
      t.integer :entry_id,         null: false
      t.string  :term,             null: false, limit: 255
      t.integer :term_count,       null: false, default: 0
      t.datetime :entry_updated_at, null: false
    end
    add_index :entry_term_frequencies, [:entry_id, :term], unique: true
    add_index :entry_term_frequencies, :entry_id
  end
end
