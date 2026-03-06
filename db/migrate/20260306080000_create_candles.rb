class CreateCandles < ActiveRecord::Migration[8.1]
  def change
    create_table :candles do |t|
      t.bigint   "asset_id",       null: false
      t.string   "interval",       null: false, default: '4h'  # 4h, 1h, 1d, 1w
      t.datetime "candle_time",    null: false  # K线开始时间
      t.decimal  "open_price",     precision: 15, scale: 2, null: false
      t.decimal  "high_price",     precision: 15, scale: 2, null: false
      t.decimal  "low_price",      precision: 15, scale: 2, null: false
      t.decimal  "close_price",    precision: 15, scale: 2, null: false
      t.decimal  "volume",         precision: 20, scale: 2
      t.decimal  "quote_volume",   precision: 20, scale: 2  # 成交额

      t.timestamps
    end

    # 复合唯一索引：确保每个资产在每个时间周期下，每个时间点只有一条K线
    add_index :candles, [:asset_id, :interval, :candle_time], unique: true

    # 查询索引
    add_index :candles, :candle_time
    add_index :candles, [:asset_id, :interval]

    # 外键约束
    add_foreign_key :candles, :assets
  end
end
