class CreateAllocationDecisionsAndTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :allocation_decisions do |t|
      t.references :trader, null: false, foreign_key: true
      t.references :trading_strategy, null: true, foreign_key: true
      t.date :decision_date, null: false
      t.integer :status, null: false, default: 0
      t.string :source, null: false, default: "llm"
      t.string :llm_model_name
      t.integer :validation_status, null: false, default: 0
      t.string :selected_strategy
      t.text :market_analysis
      t.text :summary
      t.text :error_message
      t.jsonb :recommendation_payload, null: false, default: {}
      t.datetime :generated_at

      t.timestamps
    end

    add_index :allocation_decisions, [:trader_id, :decision_date]
    add_index :allocation_decisions, :status

    create_table :allocation_tasks do |t|
      t.references :trader, null: false, foreign_key: true
      t.references :allocation_decision, null: true, foreign_key: true
      t.date :run_on, null: false
      t.integer :status, null: false, default: 0
      t.decimal :starting_cash, precision: 15, scale: 2, null: false, default: 0
      t.decimal :ending_cash, precision: 15, scale: 2, null: false, default: 0
      t.decimal :portfolio_value, precision: 15, scale: 2, null: false, default: 0
      t.text :summary
      t.text :error_message
      t.jsonb :execution_payload, null: false, default: {}
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :allocation_tasks, [:trader_id, :run_on]
    add_index :allocation_tasks, :status

    create_table :trader_positions do |t|
      t.references :trader, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.decimal :quantity, precision: 20, scale: 8, null: false, default: 0
      t.decimal :average_cost, precision: 15, scale: 2, null: false, default: 0
      t.decimal :current_price, precision: 15, scale: 2, null: false, default: 0
      t.decimal :market_value, precision: 15, scale: 2, null: false, default: 0
      t.decimal :unrealized_pnl, precision: 15, scale: 2, null: false, default: 0
      t.decimal :unrealized_pnl_percent, precision: 8, scale: 2, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :opened_at
      t.datetime :last_rebalanced_at

      t.timestamps
    end

    add_index :trader_positions, [:trader_id, :asset_id], unique: true
    add_index :trader_positions, [:trader_id, :active]
  end
end
