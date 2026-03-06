class CreateAssetSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :asset_snapshots do |t|
      t.bigint   "asset_id",        null: false
      t.date     "snapshot_date",   null: false  # 快照日期（用于查询和唯一性约束）
      t.datetime "captured_at",     null: false  # 实际采集时间（精确时间戳）
      t.decimal  "price",           precision: 15, scale: 2, null: false
      t.decimal  "change_percent",  precision: 8,  scale: 4
      t.decimal  "volume",          precision: 20, scale: 2

      t.timestamps
    end

    # 复合唯一索引：确保每个资产每天只有一条快照
    add_index :asset_snapshots, [:asset_id, :snapshot_date], unique: true

    # 其他查询索引
    add_index :asset_snapshots, :snapshot_date
    add_index :asset_snapshots, :captured_at

    # 外键约束
    add_foreign_key :asset_snapshots, :assets
  end
end
