class ReplaceDraftWithPublishAt < ActiveRecord::Migration[6.1]
  def up
    add_column :entries, :publish_at, :datetime, default: nil
    add_index :entries, :publish_at
    # 既存の公開済みエントリに publish_at を設定
    execute("UPDATE entries SET publish_at = created_at WHERE draft = false")
    remove_column :entries, :draft
  end

  def down
    add_column :entries, :draft, :boolean, default: false
    execute("UPDATE entries SET draft = CASE WHEN publish_at IS NULL OR publish_at > NOW() THEN 1 ELSE 0 END")
    remove_column :entries, :publish_at
  end
end
