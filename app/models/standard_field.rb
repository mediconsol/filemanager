class StandardField < ApplicationRecord
  # Validations
  validates :name, presence: true, uniqueness: true, format: { with: /\A[a-z_][a-z0-9_]*\z/, message: "소문자, 숫자, 언더스코어만 사용 가능합니다" }
  validates :label, presence: true
  validates :data_type, presence: true, inclusion: { in: %w[string integer float boolean date datetime text] }
  validates :category, presence: true
  validate :category_exists
  validates :sort_order, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :required, -> { where(is_required: true) }
  scope :ordered, -> { order(:sort_order, :name) }

  # Associations
  belongs_to :category_record, class_name: 'Category', foreign_key: 'category', primary_key: 'name', optional: true

  # Constants
  DATA_TYPES = {
    'string' => '문자열',
    'integer' => '정수',
    'float' => '실수',
    'boolean' => '참/거짓',
    'date' => '날짜',
    'datetime' => '날짜시간',
    'text' => '긴 텍스트'
  }.freeze

  # Instance methods
  def category_humanized
    category_record&.label || category.humanize
  end

  def data_type_humanized
    DATA_TYPES[data_type] || data_type.humanize
  end

  def required_text
    is_required? ? '필수' : '선택'
  end

  def status_text
    is_active? ? '활성' : '비활성'
  end

  # Class methods
  def self.categories_for_select
    Category.active.ordered.pluck(:label, :name)
  end

  def self.data_types_for_select
    DATA_TYPES.map { |key, value| [value, key] }
  end

  def self.by_category_hash
    active.ordered.group_by(&:category)
  end

  private

  def category_exists
    return if category.blank?

    # 기존 하드코딩된 카테고리들은 허용
    legacy_categories = %w[financial operational quality patient custom]
    return if legacy_categories.include?(category)

    # 새로운 카테고리는 Category 테이블에 존재해야 함
    unless Category.active.exists?(name: category)
      errors.add(:category, '존재하지 않거나 비활성화된 카테고리입니다')
    end
  end
end
