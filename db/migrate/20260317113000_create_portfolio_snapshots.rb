class CreatePortfolioSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :portfolio_snapshots do |t|
      t.references :trader, null: false, foreign_key: true
      t.references :allocation_task, null: true, foreign_key: true
      t.date :snapshot_date, null: false
      t.datetime :captured_at, null: false
      t.decimal :cash_value, precision: 15, scale: 2, null: false, default: 0
      t.decimal :invested_value, precision: 15, scale: 2, null: false, default: 0
      t.decimal :portfolio_value, precision: 15, scale: 2, null: false, default: 0
      t.decimal :profit_loss, precision: 15, scale: 2, null: false, default: 0
      t.decimal :profit_loss_percent, precision: 8, scale: 2, null: false, default: 0
      t.string :source, null: false, default: "execution"
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :portfolio_snapshots, [:trader_id, :snapshot_date]
    add_index :portfolio_snapshots, [:trader_id, :captured_at]
    add_index :portfolio_snapshots, :source
  end
end
