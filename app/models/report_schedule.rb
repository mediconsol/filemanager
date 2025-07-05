class ReportSchedule < ApplicationRecord
  # Associations
  belongs_to :hospital
  belongs_to :user
  has_many :report_executions, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :frequency, presence: true, inclusion: { in: %w[daily weekly monthly quarterly yearly] }
  validates :format, presence: true, inclusion: { in: %w[pdf excel html] }
  validates :status, presence: true, inclusion: { in: %w[active inactive] }

  # Serialization
  serialize :report_config, coder: JSON
  serialize :recipients, coder: JSON
  serialize :parameters, coder: JSON

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :inactive, -> { where(status: 'inactive') }
  scope :by_frequency, ->(freq) { where(frequency: freq) }
  scope :due_for_execution, -> { where('next_run_at <= ?', Time.current) }

  # Constants
  FREQUENCIES = %w[daily weekly monthly quarterly yearly].freeze
  FORMATS = %w[pdf excel html].freeze
  STATUSES = %w[active inactive].freeze

  # Callbacks
  before_create :set_next_run_at
  after_update :update_next_run_at, if: :saved_change_to_frequency?

  # Instance methods
  def frequency_humanized
    case frequency
    when 'daily'
      '매일'
    when 'weekly'
      '매주'
    when 'monthly'
      '매월'
    when 'quarterly'
      '분기별'
    when 'yearly'
      '매년'
    else
      frequency.humanize
    end
  end

  def format_humanized
    case format
    when 'pdf'
      'PDF'
    when 'excel'
      'Excel'
    when 'html'
      'HTML'
    else
      format.upcase
    end
  end

  def status_humanized
    case status
    when 'active'
      '활성'
    when 'inactive'
      '비활성'
    else
      status.humanize
    end
  end

  def due_for_execution?
    active? && next_run_at.present? && next_run_at <= Time.current
  end

  def last_execution
    report_executions.order(created_at: :desc).first
  end

  def last_successful_execution
    report_executions.where(status: 'completed').order(created_at: :desc).first
  end

  def execution_count
    report_executions.count
  end

  def success_rate
    total = report_executions.count
    return 0 if total.zero?

    successful = report_executions.where(status: 'completed').count
    ((successful.to_f / total) * 100).round(1)
  end

  def activate!
    update!(status: 'active', next_run_at: calculate_next_run_at)
  end

  def deactivate!
    update!(status: 'inactive')
  end

  def execute_now!
    ReportExecutionJob.perform_later(self)
  end

  def update_next_run_at!
    update!(next_run_at: calculate_next_run_at)
  end

  def recipient_emails
    return [] unless recipients.present?
    recipients.map { |r| r['email'] }.compact
  end

  def add_recipient(email, name = nil)
    self.recipients ||= []
    self.recipients << { 'email' => email, 'name' => name }
    save!
  end

  def remove_recipient(email)
    return unless recipients.present?
    self.recipients.reject! { |r| r['email'] == email }
    save!
  end

  def report_config_value(key, default = nil)
    return default if report_config.blank?
    report_config.dig(key.to_s) || default
  end

  def parameter_value(key, default = nil)
    return default if parameters.blank?
    parameters.dig(key.to_s) || default
  end

  # Class methods
  def self.frequencies_for_select
    FREQUENCIES.map { |freq| [freq.humanize, freq] }
  end

  def self.formats_for_select
    FORMATS.map { |format| [format.upcase, format] }
  end

  def self.statuses_for_select
    STATUSES.map { |status| [status.humanize, status] }
  end

  def self.execute_due_reports
    due_for_execution.find_each do |schedule|
      schedule.execute_now!
    end
  end

  private

  def set_next_run_at
    self.next_run_at = calculate_next_run_at
  end

  def update_next_run_at
    self.next_run_at = calculate_next_run_at
  end

  def calculate_next_run_at
    base_time = Time.current

    case frequency
    when 'daily'
      base_time.beginning_of_day + 1.day + 9.hours # 다음날 오전 9시
    when 'weekly'
      base_time.beginning_of_week + 1.week + 1.day + 9.hours # 다음주 월요일 오전 9시
    when 'monthly'
      base_time.beginning_of_month + 1.month + 9.hours # 다음달 1일 오전 9시
    when 'quarterly'
      base_time.beginning_of_quarter + 3.months + 9.hours # 다음 분기 첫날 오전 9시
    when 'yearly'
      base_time.beginning_of_year + 1.year + 9.hours # 다음년 1월 1일 오전 9시
    else
      base_time + 1.day
    end
  end
end
