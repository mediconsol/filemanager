class DataUpload < ApplicationRecord
  # Associations
  belongs_to :hospital
  belongs_to :user
  has_many :field_mappings, dependent: :destroy
  has_many :etl_jobs, dependent: :destroy

  # Validations
  validates :file_name, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  validates :data_category, inclusion: { in: %w[financial operational quality patient] }, allow_blank: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :by_category, ->(category) { where(data_category: category) }
  scope :recent, -> { order(created_at: :desc) }

  # Serialization
  serialize :original_data, coder: JSON
  serialize :processed_data, coder: JSON
  serialize :validation_errors, coder: JSON

  # Constants
  STATUSES = %w[pending processing completed failed].freeze
  DATA_CATEGORIES = %w[financial operational quality patient].freeze
  ALLOWED_FILE_TYPES = %w[text/csv application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet].freeze

  # Instance methods
  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def file_extension
    File.extname(file_name).downcase
  end

  def csv_file?
    file_extension == '.csv'
  end

  def excel_file?
    %w[.xls .xlsx].include?(file_extension)
  end

  def file_size_mb
    return 0 if file_size.blank?
    (file_size.to_f / 1.megabyte).round(2)
  end

  def processing_duration
    return nil unless processing_started_at && processing_completed_at
    processing_completed_at - processing_started_at
  end

  def processing_duration_formatted
    duration = processing_duration
    return 'N/A' unless duration

    if duration < 60
      "#{duration.round(1)}초"
    else
      "#{(duration / 60).round(1)}분"
    end
  end

  def success_rate
    return 0 if total_rows.blank? || total_rows.zero?
    ((processed_rows.to_f / total_rows) * 100).round(2)
  end

  def error_rate
    return 0 if total_rows.blank? || total_rows.zero?
    ((error_rows.to_f / total_rows) * 100).round(2)
  end

  def has_errors?
    error_rows.present? && error_rows > 0
  end

  def start_processing!
    update!(
      status: 'processing',
      processing_started_at: Time.current,
      error_message: nil
    )
  end

  def complete_processing!(processed_count, error_count = 0)
    update!(
      status: 'completed',
      processing_completed_at: Time.current,
      processed_rows: processed_count,
      error_rows: error_count
    )
  end

  def fail_processing!(error_msg)
    update!(
      status: 'failed',
      processing_completed_at: Time.current,
      error_message: error_msg
    )
  end

  # Class methods
  def self.statuses_for_select
    STATUSES.map { |status| [status.humanize, status] }
  end

  def self.categories_for_select
    DATA_CATEGORIES.map { |category| [category.humanize, category] }
  end
end
