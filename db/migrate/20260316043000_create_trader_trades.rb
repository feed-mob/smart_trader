class CreateTraderTrades < ActiveRecord::Migration[8.1]
  def change
    create_table :trader_trades do |t|
      t.references :trader, null: false, foreign_key: true
      t.references :allocation_task, null: false, foreign_key: true
      t.references :allocation_decision, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.string :action, null: false
      t.decimal :quantity, precision: 20, scale: 8, null: false
      t.decimal :price, precision: 15, scale: 2, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.text :reason
      t.datetime :executed_at, null: false

      t.timestamps
    end

    add_index :trader_trades, [:trader_id, :executed_at]
    add_index :trader_trades, [:allocation_task_id, :asset_id]
    add_index :trader_trades, :action
  end
end
