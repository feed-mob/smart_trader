class CreateAiAnalysisRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_analysis_records do |t|
      t.references :user, null: false, foreign_key: true
      t.text :prompt, null: false
      t.text :files
      t.string :permission_mode, default: "default"
      t.text :output
      t.text :error
      t.boolean :success, default: false
      t.integer :files_count, default: 0
      t.string :status, default: "completed" # completed, failed

      t.timestamps
    end

    add_index :ai_analysis_records, :created_at
    add_index :ai_analysis_records, :status
  end
end
