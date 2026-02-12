# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false, index: { unique: true }
      t.string :google_id, index: { unique: true }
      t.string :avatar_url
      t.boolean :email_verified, default: false
      t.timestamps
    end

    add_index :users, [:email, :google_id], unique: true
  end
end
