class RemovePublishAtFromEntries < ActiveRecord::Migration[6.1]
  def up
    remove_index :entries, :publish_at
    remove_column :entries, :publish_at
  end

  def down
    add_column :entries, :publish_at, :datetime, default: nil
    add_index :entries, :publish_at
  end
end
