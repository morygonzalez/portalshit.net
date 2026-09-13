class RestoreDraftFlag < ActiveRecord::Migration[6.1]
  def up
    add_column :entries, :draft, :boolean, null: false, default: false

    now_func = connection.adapter_name =~ /Mysql/i ? 'NOW()' : "datetime('now')"
    execute <<~SQL
      UPDATE entries
      SET draft = CASE
                    WHEN publish_at IS NULL OR publish_at > #{now_func} THEN 1
                    ELSE 0
                  END
    SQL
  end

  def down
    remove_column :entries, :draft
  end
end
