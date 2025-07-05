class EtlJob < ApplicationRecord
  # Associations
  belongs_to :hospital
  belongs_to :data_upload
  belongs_to :user, optional: true

  # Validations
  validates :job_type, presence: true, inclusion: { in: %w[extract transform load full_etl] }
  validates :status, presence: true, inclusion: { in: %w[pending running completed failed cancelled] }
  validates :stage, presence: true, inclusion: { in: %w[raw staging core] }

  # Serialization
  serialize :job_config, coder: JSON
  serialize :error_details, coder: JSON
  serialize :processing_stats, coder: JSON

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :running, -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :by_type, ->(type) { where(job_type: type) }
  scope :by_stage, ->(stage) { where(stage: stage) }
  scope :recent, -> { order(created_at: :desc) }

  # Constants
  JOB_TYPES = %w[extract transform load full_etl].freeze
  STATUSES = %w[pending running completed failed cancelled].freeze
  STAGES = %w[raw staging core].freeze

  # Callbacks
  before_create :set_defaults
  after_update :update_data_upload_status

  # Instance methods
  def start!
    update!(
      status: 'running',
      started_at: Time.current,
      error_message: nil,
      error_details: nil
    )
  end

  def complete!(stats = {})
    update!(
      status: 'completed',
      completed_at: Time.current,
      processing_stats: stats
    )
  end

  def fail!(error_message, error_details = {})
    update!(
      status: 'failed',
      completed_at: Time.current,
      error_message: error_message,
      error_details: error_details
    )
  end

  def cancel!
    update!(
      status: 'cancelled',
      completed_at: Time.current
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

  def progress_percentage
    return 0 unless processing_stats.present?

    total = processing_stats['total_rows'] || 0
    processed = processing_stats['processed_rows'] || 0

    return 0 if total.zero?
    ((processed.to_f / total) * 100).round(1)
  end

  def job_type_humanized
    case job_type
    when 'extract'
      '추출'
    when 'transform'
      '변환'
    when 'load'
      '적재'
    when 'full_etl'
      '전체 ETL'
    else
      job_type.humanize
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
    when 'cancelled'
      '취소'
    else
      status.humanize
    end
  end

  def stage_humanized
    case stage
    when 'raw'
      'Raw 데이터'
    when 'staging'
      'Staging 데이터'
    when 'core'
      'Core 데이터'
    else
      stage.humanize
    end
  end

  def can_restart?
    %w[failed cancelled].include?(status)
  end

  def can_cancel?
    %w[pending running].include?(status)
  end

  def processing_stat(key, default = 0)
    return default if processing_stats.blank?
    processing_stats.dig(key.to_s) || default
  end

  def error_detail(key, default = nil)
    return default if error_details.blank?
    error_details.dig(key.to_s) || default
  end

  def job_config_value(key, default = nil)
    return default if job_config.blank?
    job_config.dig(key.to_s) || default
  end

  # Class methods
  def self.job_types_for_select
    JOB_TYPES.map { |type| [type.humanize, type] }
  end

  def self.statuses_for_select
    STATUSES.map { |status| [status.humanize, status] }
  end

  def self.stages_for_select
    STAGES.map { |stage| [stage.humanize, stage] }
  end

  def self.create_etl_pipeline(data_upload, user = nil)
    jobs = []

    # Extract job
    jobs << create!(
      hospital: data_upload.hospital,
      data_upload: data_upload,
      user: user,
      job_type: 'extract',
      stage: 'raw',
      status: 'pending',
      job_config: { source_file: data_upload.file_path }
    )

    # Transform job
    jobs << create!(
      hospital: data_upload.hospital,
      data_upload: data_upload,
      user: user,
      job_type: 'transform',
      stage: 'staging',
      status: 'pending',
      job_config: { apply_mappings: true, validate_data: true }
    )

    # Load job
    jobs << create!(
      hospital: data_upload.hospital,
      data_upload: data_upload,
      user: user,
      job_type: 'load',
      stage: 'core',
      status: 'pending',
      job_config: { target_tables: determine_target_tables(data_upload) }
    )

    jobs
  end

  private

  def set_defaults
    self.status ||= 'pending'
    self.stage ||= 'raw'
    self.job_config ||= {}
    self.processing_stats ||= {}
  end

  def update_data_upload_status
    return unless saved_change_to_status?

    case status
    when 'running'
      data_upload.update(status: 'processing') if data_upload.pending?
    when 'completed'
      # 모든 ETL 작업이 완료되었는지 확인
      if data_upload.etl_jobs.where.not(status: 'completed').empty?
        data_upload.update(status: 'completed')
      end
    when 'failed'
      data_upload.update(
        status: 'failed',
        error_message: error_message
      )
    end
  end

  def self.determine_target_tables(data_upload)
    case data_upload.data_category
    when 'financial'
      ['financial_data', 'revenue_data', 'cost_data']
    when 'operational'
      ['operational_data', 'bed_data', 'staff_data']
    when 'quality'
      ['quality_data', 'patient_satisfaction', 'outcome_data']
    when 'patient'
      ['patient_data', 'admission_data', 'diagnosis_data']
    else
      ['general_data']
    end
  end
end
