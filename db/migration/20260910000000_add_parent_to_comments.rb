# frozen_string_literal: true

class AddParentToComments < ActiveRecord::Migration[4.2]
  def change
    add_column :comments, :parent_id, :integer
    add_index :comments, :parent_id
  end
end
