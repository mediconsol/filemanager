class CreateReportSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :report_schedules do |t|
      t.references :hospital, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.string :report_type
      t.string :schedule_type
      t.text :schedule_config
      t.text :recipients
      t.datetime :last_run_at
      t.datetime :next_run_at
      t.boolean :is_active

      t.timestamps
    end
  end
end
