class AddStatusToReportSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :report_schedules, :status, :string, default: 'active'
    add_index :report_schedules, :status
  end
end
