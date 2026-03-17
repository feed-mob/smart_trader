# frozen_string_literal: true

class CreateJobExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :job_executions do |t|
      t.string :job_id, null: false
      t.string :job_name, null: false
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :duration_ms
      t.text :arguments
      t.text :error_message
      t.string :queue_name

      t.timestamps
    end

    add_index :job_executions, :job_name
    add_index :job_executions, :job_id, unique: true
    add_index :job_executions, :started_at
    add_index :job_executions, :status
  end
end
