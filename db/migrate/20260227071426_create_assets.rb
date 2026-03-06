class CreateAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :assets do |t|
      t.string   "symbol",          null: false
      t.string   "name",            null: false
      t.string   "asset_type",      null: false  # enum: crypto, stock, commodity, etf
      t.string   "exchange",        null: false, default: 'UNKNOWN'
      t.string   "quote_currency",  null: false, default: 'USD'
      t.string   "coingecko_id"                   # CoinGecko 币种 ID (仅加密货币)
      t.string   "yahoo_symbol"                   # Yahoo Finance Symbol (如 BTC-USD, AAPL)
      t.decimal  "current_price",   precision: 15, scale: 2
      t.datetime "last_updated"
      t.boolean  "active",          null: false, default: true

      t.timestamps
    end

    # 复合唯一索引：同一 symbol 在不同交易所和计价货币下可以存在
    add_index :assets, [:symbol, :exchange, :quote_currency], unique: true

    # 外部数据源索引
    add_index :assets, :coingecko_id, unique: true
    add_index :assets, :yahoo_symbol, unique: true

    # 其他查询索引
    add_index :assets, :asset_type
    add_index :assets, :active
  end
end
