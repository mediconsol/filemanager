class AdminCenter::UsersController < ApplicationController
  before_action :ensure_admin_access
  before_action :set_user, only: [:show, :edit, :update, :destroy, :activate, :deactivate, :reset_password]
  
  def index
    @users = User.includes(:hospital)
                 .order(created_at: :desc)
                 .page(params[:page])
                 .per(20)
    
    # 필터링
    @users = @users.where(hospital_id: params[:hospital_id]) if params[:hospital_id].present?
    @users = @users.where(role: params[:role]) if params[:role].present?
    @users = @users.where(is_active: params[:is_active]) if params[:is_active].present?
    
    # 검색
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @users = @users.where("name ILIKE ? OR email ILIKE ?", search_term, search_term)
    end
    
    @hospitals = Hospital.active.order(:name)
    @user_stats = calculate_user_stats
  end

  def show
    @user_activities = get_user_activities(@user)
    @user_stats = get_user_statistics(@user)
  end

  def new
    @user = User.new
    @hospitals = Hospital.active.order(:name)
  end

  def create
    @user = User.new(user_params)
    @user.password = generate_temporary_password
    
    if @user.save
      # 임시 비밀번호 이메일 발송
      UserMailer.welcome_email(@user, @user.password).deliver_later
      
      redirect_to admin_center_user_path(@user), notice: '사용자가 생성되었습니다. 임시 비밀번호가 이메일로 발송되었습니다.'
    else
      @hospitals = Hospital.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @hospitals = Hospital.active.order(:name)
  end

  def update
    if @user.update(user_params)
      redirect_to admin_center_user_path(@user), notice: '사용자 정보가 수정되었습니다.'
    else
      @hospitals = Hospital.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user.admin? && User.where(role: 'admin').count <= 1
      redirect_to admin_center_users_path, alert: '마지막 관리자는 삭제할 수 없습니다.'
      return
    end
    
    @user.destroy
    redirect_to admin_center_users_path, notice: '사용자가 삭제되었습니다.'
  end

  def activate
    @user.update!(is_active: true)
    redirect_to admin_center_user_path(@user), notice: '사용자가 활성화되었습니다.'
  end

  def deactivate
    if @user.admin? && User.where(role: 'admin', is_active: true).count <= 1
      redirect_to admin_center_user_path(@user), alert: '마지막 활성 관리자는 비활성화할 수 없습니다.'
      return
    end
    
    @user.update!(is_active: false)
    redirect_to admin_center_user_path(@user), notice: '사용자가 비활성화되었습니다.'
  end

  def reset_password
    new_password = generate_temporary_password
    @user.update!(password: new_password)
    
    # 새 비밀번호 이메일 발송
    UserMailer.password_reset_email(@user, new_password).deliver_later
    
    redirect_to admin_center_user_path(@user), notice: '비밀번호가 재설정되었습니다. 새 비밀번호가 이메일로 발송되었습니다.'
  end

  def bulk_action
    user_ids = params[:user_ids] || []
    action = params[:bulk_action]
    
    if user_ids.empty?
      redirect_to admin_center_users_path, alert: '사용자를 선택해주세요.'
      return
    end
    
    users = User.where(id: user_ids)
    
    case action
    when 'activate'
      users.update_all(is_active: true)
      redirect_to admin_center_users_path, notice: "#{users.count}명의 사용자가 활성화되었습니다."
    when 'deactivate'
      # 관리자 보호 로직
      admin_count = User.where(role: 'admin', is_active: true).count
      admin_to_deactivate = users.where(role: 'admin').count
      
      if admin_count - admin_to_deactivate < 1
        redirect_to admin_center_users_path, alert: '최소 한 명의 활성 관리자가 필요합니다.'
        return
      end
      
      users.update_all(is_active: false)
      redirect_to admin_center_users_path, notice: "#{users.count}명의 사용자가 비활성화되었습니다."
    when 'delete'
      # 관리자 보호 로직
      admin_count = User.where(role: 'admin').count
      admin_to_delete = users.where(role: 'admin').count
      
      if admin_count - admin_to_delete < 1
        redirect_to admin_center_users_path, alert: '최소 한 명의 관리자가 필요합니다.'
        return
      end
      
      users.destroy_all
      redirect_to admin_center_users_path, notice: "#{users.count}명의 사용자가 삭제되었습니다."
    else
      redirect_to admin_center_users_path, alert: '잘못된 작업입니다.'
    end
  end

  private

  def ensure_admin_access
    unless current_user&.admin?
      redirect_to root_path, alert: '관리자 권한이 필요합니다.'
    end
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :role, :hospital_id, :is_active)
  end

  def generate_temporary_password
    SecureRandom.alphanumeric(12)
  end

  def calculate_user_stats
    {
      total: User.count,
      active: User.active.count,
      inactive: User.inactive.count,
      admins: User.where(role: 'admin').count,
      analysts: User.where(role: 'analyst').count,
      viewers: User.where(role: 'viewer').count,
      recent_logins: User.where('last_login_at > ?', 24.hours.ago).count,
      never_logged_in: User.where(last_login_at: nil).count
    }
  end

  def get_user_activities(user)
    activities = []
    
    # 데이터 업로드 활동
    user.data_uploads.order(created_at: :desc).limit(10).each do |upload|
      activities << {
        type: 'data_upload',
        description: "데이터 업로드: #{upload.file_name}",
        timestamp: upload.created_at,
        status: upload.status
      }
    end
    
    # 분석 생성 활동
    user.analysis_results.order(created_at: :desc).limit(10).each do |analysis|
      activities << {
        type: 'analysis_creation',
        description: "분석 생성: #{analysis.description.presence || "분석 ##{analysis.id}"}",
        timestamp: analysis.created_at,
        status: 'completed'
      }
    end
    
    # 리포트 스케줄 활동
    user.report_schedules.order(created_at: :desc).limit(10).each do |schedule|
      activities << {
        type: 'report_schedule',
        description: "리포트 스케줄 생성: #{schedule.name}",
        timestamp: schedule.created_at,
        status: schedule.status
      }
    end
    
    # 시간순 정렬
    activities.sort_by { |activity| activity[:timestamp] }.reverse.first(20)
  end

  def get_user_statistics(user)
    {
      total_uploads: user.data_uploads.count,
      successful_uploads: user.data_uploads.where(status: 'completed').count,
      total_analyses: user.analysis_results.count,
      total_reports: user.report_schedules.count,
      active_reports: user.report_schedules.active.count,
      last_login: user.last_login_at,
      account_age: user.created_at
    }
  end
end
