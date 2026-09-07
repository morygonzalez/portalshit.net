# frozen_string_literal: true

class AddPrivateToComments < ActiveRecord::Migration[4.2]
  def up
    add_column :comments, :private, :boolean, default: false, null: false
  end

  def down
    if select_value('SELECT COUNT(*) FROM comments WHERE private = TRUE').to_i.positive?
      raise ActiveRecord::IrreversibleMigration, 'Private comments must be safely removed before rollback'
    end
    remove_column :comments, :private
  end
end
