class Category < ApplicationRecord
  # Associations
  has_many :standard_fields, foreign_key: 'category', primary_key: 'name', dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, uniqueness: true, format: { with: /\A[a-z_][a-z0-9_]*\z/, message: "소문자, 숫자, 언더스코어만 사용 가능합니다" }
  validates :label, presence: true
  validates :sort_order, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:sort_order, :name) }

  # Instance methods
  def status_text
    is_active? ? '활성' : '비활성'
  end

  def fields_count
    standard_fields.count
  end

  def active_fields_count
    standard_fields.active.count
  end

  def required_fields_count
    standard_fields.required.count
  end

  # Class methods
  def self.for_select
    active.ordered.pluck(:label, :name)
  end

  def self.with_stats
    includes(:standard_fields).map do |category|
      {
        category: category,
        total_fields: category.fields_count,
        active_fields: category.active_fields_count,
        required_fields: category.required_fields_count
      }
    end
  end
end
