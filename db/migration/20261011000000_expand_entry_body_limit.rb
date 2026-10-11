# frozen_string_literal: true

class ExpandEntryBodyLimit < ActiveRecord::Migration[6.1]
  TEXT_LIMIT = 65_535
  MEDIUMTEXT_LIMIT = 16_777_215

  def up
    change_column :entries, :body, :text, limit: MEDIUMTEXT_LIMIT
  end

  def down
    # SQLite の LENGTH(text) は文字数なので、バイト数を確認するため BLOB にする。
    byte_length = connection.adapter_name =~ /SQLite/i ? 'LENGTH(CAST(body AS BLOB))' : 'OCTET_LENGTH(body)'
    if select_value("SELECT 1 FROM entries WHERE #{byte_length} > #{TEXT_LIMIT} LIMIT 1")
      raise ActiveRecord::IrreversibleMigration, '本文が65,535バイトを超える記事があるため、TEXT型には戻せません。'
    end

    change_column :entries, :body, :text, limit: TEXT_LIMIT
  end
end
