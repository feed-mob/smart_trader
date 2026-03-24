# frozen_string_literal: true

class CreateTraderReflections < ActiveRecord::Migration[8.1]
  def change
    create_table :trader_reflections do |t|
      t.references :trader, null: false, foreign_key: true
      t.references :trading_strategy, null: true, foreign_key: true
      t.date :reflection_period_start, null: false
      t.date :reflection_period_end, null: false
      t.integer :status, null: false, default: 0
      t.string :source, null: false, default: "llm"
      t.string :prompt_version, null: false, default: "v1"
      t.jsonb :metrics, null: false, default: {}
      t.text :llm_summary
      t.jsonb :findings, null: false, default: {}
      t.jsonb :suggested_adjustments, null: false, default: []
      t.datetime :generated_at
      t.text :error_message

      t.timestamps
    end

    add_index :trader_reflections, [:trader_id, :reflection_period_start, :reflection_period_end],
              unique: true, name: "index_trader_reflections_on_trader_and_period"
  end
end
