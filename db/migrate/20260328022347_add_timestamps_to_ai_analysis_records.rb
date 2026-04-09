class AddTimestampsToAiAnalysisRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_analysis_records, :started_at, :datetime
    add_column :ai_analysis_records, :finished_at, :datetime
  end
end
