class AddMarketConditionToTradingStrategies < ActiveRecord::Migration[8.1]
  def change
    # Remove unique constraint to allow multiple strategies per trader
    remove_index :trading_strategies, :trader_id

    # Add market_condition enum (0: normal, 1: volatile, 2: crash, 3: bubble)
    add_column :trading_strategies, :market_condition, :integer, default: 0, null: false

    # Add new indexes
    add_index :trading_strategies, [:trader_id, :market_condition], unique: true
  end
end
