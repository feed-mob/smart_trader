class CreateTradingStrategies < ActiveRecord::Migration[8.1]
  def change
    create_table :trading_strategies do |t|
      t.integer :trader_id, null: false
      t.string :name, null: false
      t.integer :market_condition, default: 0, null: false  # 0: normal, 1: volatile, 2: crash, 3: bubble
      t.integer :risk_level, default: 1  # 0: conservative, 1: balanced, 2: aggressive
      t.integer :max_positions, default: 3  # 2-5
      t.decimal :buy_signal_threshold, precision: 3, scale: 2, default: 0.5  # 0.3-0.7
      t.decimal :max_position_size, precision: 3, scale: 2, default: 0.5  # 0.3-0.7
      t.decimal :min_cash_reserve, precision: 3, scale: 2, default: 0.2  # 0.05-0.4
      t.text :description
      t.integer :generated_by, default: 0  # 0: llm, 1: manual, 2: default, 3: matrix

      t.timestamps
    end

    add_index :trading_strategies, [:trader_id, :market_condition], unique: true
  end
end
