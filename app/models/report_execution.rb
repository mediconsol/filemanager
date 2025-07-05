class ReportExecution < ApplicationRecord
  # Associations
  belongs_to :report_schedule

  # Validations
  validates :status, presence: true, inclusion: { in: %w[pending running completed failed] }

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :running, -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(created_at: :desc) }

  # Constants
  STATUSES = %w[pending running completed failed].freeze

  # Callbacks
  before_create :set_defaults

  # Instance methods
  def start!
    update!(
      status: 'running',
      started_at: Time.current,
      error_message: nil
    )
  end

  def complete!(file_path, file_size = nil)
    update!(
      status: 'completed',
      completed_at: Time.current,
      file_path: file_path,
      file_size: file_size,
      execution_time: calculate_execution_time
    )
  end

  def fail!(error_message)
    update!(
      status: 'failed',
      completed_at: Time.current,
      error_message: error_message,
      execution_time: calculate_execution_time
    )
  end

  def duration
    return nil unless started_at.present?
    end_time = completed_at || Time.current
    end_time - started_at
  end

  def duration_formatted
    return '-' unless duration.present?

    seconds = duration.to_i
    if seconds < 60
      "#{seconds}초"
    elsif seconds < 3600
      "#{seconds / 60}분 #{seconds % 60}초"
    else
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      "#{hours}시간 #{minutes}분"
    end
  end

  def status_humanized
    case status
    when 'pending'
      '대기'
    when 'running'
      '실행중'
    when 'completed'
      '완료'
    when 'failed'
      '실패'
    else
      status.humanize
    end
  end

  def file_size_mb
    return 0 unless file_size.present?
    (file_size.to_f / 1.megabyte).round(2)
  end

  def file_exists?
    file_path.present? && File.exist?(file_path)
  end

  def download_url
    return nil unless file_exists?
    # 실제 구현에서는 secure download URL 생성
    "/downloads/reports/#{File.basename(file_path)}"
  end

  # Class methods
  def self.statuses_for_select
    STATUSES.map { |status| [status.humanize, status] }
  end

  def self.cleanup_old_executions(days = 30)
    where('created_at < ?', days.days.ago).destroy_all
  end

  private

  def set_defaults
    self.status ||= 'pending'
  end

  def calculate_execution_time
    return nil unless started_at.present?
    duration.to_i
  end
end
