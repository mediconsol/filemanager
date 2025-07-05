class CreateReportExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :report_executions do |t|
      t.references :report_schedule, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at
      t.string :file_path
      t.integer :file_size
      t.text :error_message
      t.integer :execution_time

      t.timestamps
    end
  end
end
