class CreateAssetSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :asset_snapshots do |t|
      t.bigint   "asset_id",        null: false
      t.decimal  "price",           precision: 15, scale: 2, null: false
      t.decimal  "change_percent",  precision: 8,  scale: 4
      t.decimal  "volume",          precision: 20, scale: 0
      t.datetime "captured_at",     null: false

      t.timestamps
    end

    add_index :asset_snapshots, ["asset_id"]
    add_index :asset_snapshots, ["captured_at"]
    add_index :asset_snapshots, ["asset_id", "captured_at"]
    add_foreign_key :asset_snapshots, :assets
  end
end
