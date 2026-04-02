class CreateDailyReports < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_reports do |t|
      t.string :report_type, null: false
      t.date :report_date, null: false
      t.text :content, null: false
      t.text :summary
      t.jsonb :statistics, default: {}
      t.string :generated_by, default: 'ai'
      t.string :model_version
      t.integer :generation_time_ms
      t.boolean :published, default: false

      t.timestamps
    end

    # 联合唯一索引：同一日期同一类型只能有一份日报
    add_index :daily_reports, [:report_type, :report_date], unique: true
    add_index :daily_reports, :report_type
    add_index :daily_reports, :report_date
    add_index :daily_reports, :published
  end
end
