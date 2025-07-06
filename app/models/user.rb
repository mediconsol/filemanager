class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable

  # Associations
  belongs_to :hospital, optional: true
  has_many :data_uploads, dependent: :destroy
  has_many :analysis_results, dependent: :destroy
  has_many :report_schedules, dependent: :destroy
  has_many :created_etl_jobs, class_name: 'EtlJob', foreign_key: 'user_id', dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :role, presence: true, inclusion: { in: %w[admin analyst viewer] }
  validates :email, uniqueness: true
  validates :phone, format: { with: /\A[\d\-\+\(\)\s]+\z/, message: "올바른 전화번호 형식이 아닙니다" }, allow_blank: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_role, ->(role) { where(role: role) }
  scope :by_hospital, ->(hospital_id) { where(hospital_id: hospital_id) }
  scope :by_department, ->(department) { where(department: department) }

  # Enums (using string values for better readability)
  ROLES = %w[admin analyst viewer].freeze

  # Instance methods
  def admin?
    role == 'admin'
  end

  def analyst?
    role == 'analyst'
  end

  def viewer?
    role == 'viewer'
  end

  def can_manage_users?
    admin?
  end

  def can_upload_data?
    admin? || analyst?
  end

  def can_create_reports?
    admin? || analyst?
  end

  def can_view_all_data?
    admin? || analyst?
  end

  def full_name
    name
  end

  def display_name
    "#{name} (#{department})" if department.present?
    name
  end

  def update_last_login!
    update_column(:last_login_at, Time.current)
  end

  # Class methods
  def self.roles_for_select
    ROLES.map { |role| [role.humanize, role] }
  end
end
