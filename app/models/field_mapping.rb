class FieldMapping < ApplicationRecord
  # Associations
  belongs_to :hospital
  belongs_to :data_upload

  # Validations
  validates :source_field, presence: true
  validates :target_field, presence: true
  validates :mapping_type, presence: true, inclusion: { in: %w[direct calculated lookup conditional] }
  validates :data_type, presence: true, inclusion: { in: %w[string integer decimal boolean date datetime] }

  # Serialization
  serialize :transformation_rules, coder: JSON
  serialize :validation_rules, coder: JSON

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :required, -> { where(is_required: true) }
  scope :by_type, ->(type) { where(mapping_type: type) }
  scope :by_data_type, ->(data_type) { where(data_type: data_type) }

  # Constants
  MAPPING_TYPES = %w[direct calculated lookup conditional].freeze
  DATA_TYPES = %w[string integer decimal boolean date datetime].freeze

  # Instance methods
  def mapping_type_humanized
    case mapping_type
    when 'direct'
      '직접 매핑'
    when 'calculated'
      '계산'
    when 'lookup'
      '룩업'
    when 'conditional'
      '조건부'
    else
      mapping_type.humanize
    end
  end

  def data_type_humanized
    case data_type
    when 'string'
      '문자열'
    when 'integer'
      '정수'
    when 'decimal'
      '소수'
    when 'boolean'
      '불린'
    when 'date'
      '날짜'
    when 'datetime'
      '날짜시간'
    else
      data_type.humanize
    end
  end

  def has_transformation_rules?
    transformation_rules.present? && transformation_rules.any?
  end

  def has_validation_rules?
    validation_rules.present? && validation_rules.any?
  end

  def transformation_rule(key, default = nil)
    return default if transformation_rules.blank?
    transformation_rules.dig(key.to_s) || default
  end

  def validation_rule(key, default = nil)
    return default if validation_rules.blank?
    validation_rules.dig(key.to_s) || default
  end

  # Class methods
  def self.mapping_types_for_select
    MAPPING_TYPES.map { |type| [type.humanize, type] }
  end

  def self.data_types_for_select
    DATA_TYPES.map { |type| [type.humanize, type] }
  end
end
