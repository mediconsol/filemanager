class AnalysisResult < ApplicationRecord
  # Associations
  belongs_to :hospital
  belongs_to :user

  # Validations
  validates :analysis_type, presence: true
  validates :result_data, presence: true

  # Serialization
  serialize :parameters, coder: JSON
  serialize :result_data, coder: JSON
  serialize :chart_config, coder: JSON

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(analysis_type: type) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  # Constants
  ANALYSIS_TYPES = %w[financial operational quality patient custom].freeze

  # Instance methods
  def analysis_type_humanized
    case analysis_type
    when 'financial'
      '재무 분석'
    when 'operational'
      '운영 분석'
    when 'quality'
      '품질 분석'
    when 'patient'
      '환자 분석'
    when 'custom'
      '사용자 정의 분석'
    else
      analysis_type.humanize
    end
  end

  def has_chart?
    chart_config.present?
  end

  def parameter_value(key, default = nil)
    return default if parameters.blank?
    parameters.dig(key.to_s) || default
  end

  def result_value(key, default = nil)
    return default if result_data.blank?
    result_data.dig(key.to_s) || default
  end

  # Class methods
  def self.analysis_types_for_select
    ANALYSIS_TYPES.map { |type| [type.humanize, type] }
  end
end
