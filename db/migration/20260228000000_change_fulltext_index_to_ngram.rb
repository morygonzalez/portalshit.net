# frozen_string_literal: true

class ChangeFulltextIndexToNgram < ActiveRecord::Migration[6.0]
  def up
    execute "ALTER TABLE entries DROP INDEX index_entry_fulltext"
    execute "ALTER TABLE entries ADD FULLTEXT INDEX index_entry_fulltext (title, body) WITH PARSER ngram"
  end

  def down
    execute "ALTER TABLE entries DROP INDEX index_entry_fulltext"
    execute "ALTER TABLE entries ADD FULLTEXT INDEX index_entry_fulltext (title, body)"
  end
end
