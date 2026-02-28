class CreateAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :assets do |t|
      t.string   "symbol",       null: false
      t.string   "name",         null: false
      t.string   "asset_type",   null: false  # enum: crypto, stock, commodity
      t.decimal  "current_price", precision: 15, scale: 2
      t.datetime "last_updated"

      t.timestamps
    end

    add_index :assets, :symbol, unique: true
  end
end
