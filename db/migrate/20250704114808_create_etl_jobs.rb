class CreateEtlJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :etl_jobs do |t|
      t.references :hospital, null: false, foreign_key: true
      t.references :data_upload, null: false, foreign_key: true
      t.string :job_type
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.integer :processed_records
      t.integer :total_records

      t.timestamps
    end
  end
end
