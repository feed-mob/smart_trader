class CreateStrategyAdjustmentLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :strategy_adjustment_logs do |t|
      t.references :trader_reflection, null: false, foreign_key: true
      t.references :trading_strategy, null: false, foreign_key: true
      t.string :parameter, null: false
      t.string :direction, null: false
      t.text :reason
      t.decimal :before_value, precision: 12, scale: 4, null: false
      t.decimal :after_value, precision: 12, scale: 4, null: false
      t.datetime :applied_at, null: false

      t.timestamps
    end
  end
end
