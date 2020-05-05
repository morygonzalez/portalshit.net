# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[4.2]
  def change
    return if table_exists? :users

    create_table :users do |t|
      t.string  :name,             limit: 40, unique: true
      t.string  :email,            limit: 40, unique: true
      t.string  :password_digest,  limit: 60
      t.integer :permission_level, default: 1

      t.timestamps
    end
  end
end
