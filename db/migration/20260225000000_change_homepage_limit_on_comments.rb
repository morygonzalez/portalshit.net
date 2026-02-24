# frozen_string_literal: true

class ChangeHomepageLimitOnComments < ActiveRecord::Migration[4.2]
  def up
    change_column :comments, :homepage, :string, limit: 255
  end

  def down
    change_column :comments, :homepage, :string, limit: 50
  end
end
