class ReplaceDraftWithPublishAt < ActiveRecord::Migration[6.1]
  def up
    add_column :entries, :publish_at, :datetime, default: nil
    add_index :entries, :publish_at
    # 既存の公開済みエントリに publish_at を設定
    execute("UPDATE entries SET publish_at = created_at WHERE draft = 0")
    remove_column :entries, :draft
  end

  def down
    add_column :entries, :draft, :boolean, default: false
    now_func = connection.adapter_name =~ /Mysql/i ? 'NOW()' : "datetime('now')"
    execute("UPDATE entries SET draft = CASE WHEN publish_at IS NULL OR publish_at > #{now_func} THEN 1 ELSE 0 END")
    remove_column :entries, :publish_at
  end
end
