class Hospital < ApplicationRecord
  # Associations
  has_many :users, dependent: :destroy
  has_many :data_uploads, dependent: :destroy
  has_many :field_mappings, dependent: :destroy
  has_many :analysis_results, dependent: :destroy
  has_many :report_schedules, dependent: :destroy
  has_many :etl_jobs, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :plan, presence: true, inclusion: { in: %w[basic pro enterprise] }
  validates :domain, uniqueness: true, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, format: { with: /\A[\d\-\+\(\)\s]+\z/ }, allow_blank: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_plan, ->(plan) { where(plan: plan) }

  # Serialization for settings
  serialize :settings, coder: JSON

  # Constants
  PLANS = %w[basic pro enterprise].freeze

  # Instance methods
  def basic_plan?
    plan == 'basic'
  end

  def pro_plan?
    plan == 'pro'
  end

  def enterprise_plan?
    plan == 'enterprise'
  end

  def admin_users
    users.where(role: 'admin')
  end

  def analyst_users
    users.where(role: 'analyst')
  end

  def viewer_users
    users.where(role: 'viewer')
  end

  def total_users_count
    users.active.count
  end

  def total_data_uploads_count
    data_uploads.count
  end

  def recent_data_uploads(limit = 10)
    data_uploads.order(created_at: :desc).limit(limit)
  end

  def settings_value(key, default = nil)
    return default if settings.blank?
    settings.dig(key.to_s) || default
  end

  def update_setting(key, value)
    current_settings = settings || {}
    current_settings[key.to_s] = value
    update(settings: current_settings)
  end

  # Class methods
  def self.plans_for_select
    PLANS.map { |plan| [plan.humanize, plan] }
  end

  def self.default_hospital
    find_or_create_by(domain: 'default') do |hospital|
      hospital.name = '기본 병원'
      hospital.plan = 'basic'
      hospital.settings = { is_default: true }
    end
  end
end
