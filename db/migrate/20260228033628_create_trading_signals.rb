class CreateTradingSignals < ActiveRecord::Migration[8.1]
  def change
    create_table :trading_signals do |t|
      t.references :asset, null: false, foreign_key: true
      t.string :signal_type, null: false
      t.decimal :confidence, precision: 3, scale: 2
      t.text :reasoning
      t.jsonb :key_factors, default: []
      t.text :risk_warning
      t.jsonb :factor_snapshot, default: {}
      t.datetime :generated_at, null: false

      t.timestamps
    end

    add_index :trading_signals, [ :asset_id, :generated_at ]
    add_index :trading_signals, :signal_type
  end
end
