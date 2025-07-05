class AdminCenter::HospitalsController < ApplicationController
  before_action :ensure_admin_access
  before_action :set_hospital, only: [:show, :edit, :update, :destroy, :activate, :deactivate]
  
  def index
    @hospitals = Hospital.includes(:users, :data_uploads)
                        .order(created_at: :desc)
                        .page(params[:page])
                        .per(20)
    
    # 필터링
    @hospitals = @hospitals.where(is_active: params[:is_active]) if params[:is_active].present?
    
    # 검색
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @hospitals = @hospitals.where("name ILIKE ? OR address ILIKE ?", search_term, search_term)
    end
    
    @hospital_stats = calculate_hospital_stats
  end

  def show
    @hospital_activities = get_hospital_activities(@hospital)
    @hospital_stats = get_hospital_statistics(@hospital)
    @recent_users = @hospital.users.order(created_at: :desc).limit(10)
    @recent_uploads = @hospital.data_uploads.order(created_at: :desc).limit(10)
  end

  def new
    @hospital = Hospital.new
  end

  def create
    @hospital = Hospital.new(hospital_params)
    
    if @hospital.save
      redirect_to admin_center_hospital_path(@hospital), notice: '병원이 생성되었습니다.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @hospital.update(hospital_params)
      redirect_to admin_center_hospital_path(@hospital), notice: '병원 정보가 수정되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @hospital.users.any?
      redirect_to admin_center_hospitals_path, alert: '사용자가 있는 병원은 삭제할 수 없습니다.'
      return
    end
    
    @hospital.destroy
    redirect_to admin_center_hospitals_path, notice: '병원이 삭제되었습니다.'
  end

  def activate
    @hospital.update!(is_active: true)
    redirect_to admin_center_hospital_path(@hospital), notice: '병원이 활성화되었습니다.'
  end

  def deactivate
    @hospital.update!(is_active: false)
    redirect_to admin_center_hospital_path(@hospital), notice: '병원이 비활성화되었습니다.'
  end

  def bulk_action
    hospital_ids = params[:hospital_ids] || []
    action = params[:bulk_action]
    
    if hospital_ids.empty?
      redirect_to admin_center_hospitals_path, alert: '병원을 선택해주세요.'
      return
    end
    
    hospitals = Hospital.where(id: hospital_ids)
    
    case action
    when 'activate'
      hospitals.update_all(is_active: true)
      redirect_to admin_center_hospitals_path, notice: "#{hospitals.count}개 병원이 활성화되었습니다."
    when 'deactivate'
      hospitals.update_all(is_active: false)
      redirect_to admin_center_hospitals_path, notice: "#{hospitals.count}개 병원이 비활성화되었습니다."
    when 'delete'
      hospitals_with_users = hospitals.joins(:users).distinct
      if hospitals_with_users.any?
        redirect_to admin_center_hospitals_path, alert: '사용자가 있는 병원은 삭제할 수 없습니다.'
        return
      end
      
      hospitals.destroy_all
      redirect_to admin_center_hospitals_path, notice: "#{hospitals.count}개 병원이 삭제되었습니다."
    else
      redirect_to admin_center_hospitals_path, alert: '잘못된 작업입니다.'
    end
  end

  def data_summary
    @hospital = Hospital.find(params[:id])
    
    # 데이터 요약 정보
    @data_summary = {
      total_uploads: @hospital.data_uploads.count,
      successful_uploads: @hospital.data_uploads.where(status: 'completed').count,
      failed_uploads: @hospital.data_uploads.where(status: 'failed').count,
      total_size: @hospital.data_uploads.sum(:file_size) || 0,
      recent_uploads: @hospital.data_uploads.order(created_at: :desc).limit(10)
    }
    
    # 테이블별 데이터 현황
    @table_stats = get_table_statistics(@hospital)
    
    render json: {
      success: true,
      data_summary: @data_summary,
      table_stats: @table_stats
    }
  end

  private

  def ensure_admin_access
    unless current_user&.admin?
      redirect_to root_path, alert: '관리자 권한이 필요합니다.'
    end
  end

  def set_hospital
    @hospital = Hospital.find(params[:id])
  end

  def hospital_params
    params.require(:hospital).permit(:name, :address, :phone, :email, :is_active, :description)
  end

  def calculate_hospital_stats
    {
      total: Hospital.count,
      active: Hospital.active.count,
      inactive: Hospital.inactive.count,
      with_users: Hospital.joins(:users).distinct.count,
      with_data: Hospital.joins(:data_uploads).distinct.count,
      without_users: Hospital.left_joins(:users).where(users: { id: nil }).count
    }
  end

  def get_hospital_activities(hospital)
    activities = []
    
    # 사용자 등록 활동
    hospital.users.order(created_at: :desc).limit(5).each do |user|
      activities << {
        type: 'user_registration',
        description: "새 사용자 등록: #{user.name}",
        timestamp: user.created_at,
        user: user
      }
    end
    
    # 데이터 업로드 활동
    hospital.data_uploads.order(created_at: :desc).limit(10).each do |upload|
      activities << {
        type: 'data_upload',
        description: "데이터 업로드: #{upload.file_name}",
        timestamp: upload.created_at,
        user: upload.user,
        status: upload.status
      }
    end
    
    # 분석 생성 활동
    hospital.analysis_results.order(created_at: :desc).limit(5).each do |analysis|
      activities << {
        type: 'analysis_creation',
        description: "분석 생성: #{analysis.description.presence || "분석 ##{analysis.id}"}",
        timestamp: analysis.created_at,
        user: analysis.user
      }
    end
    
    # 시간순 정렬
    activities.sort_by { |activity| activity[:timestamp] }.reverse.first(20)
  end

  def get_hospital_statistics(hospital)
    {
      total_users: hospital.users.count,
      active_users: hospital.users.active.count,
      total_uploads: hospital.data_uploads.count,
      successful_uploads: hospital.data_uploads.where(status: 'completed').count,
      total_analyses: hospital.analysis_results.count,
      total_reports: hospital.report_schedules.count,
      active_reports: hospital.report_schedules.active.count,
      total_data_size: hospital.data_uploads.sum(:file_size) || 0,
      created_at: hospital.created_at
    }
  end

  def get_table_statistics(hospital)
    connection = ActiveRecord::Base.connection
    stats = {}
    
    # Core 테이블들의 데이터 현황 확인
    %w[financial operational quality patient general].each do |category|
      table_name = "core_#{category}_data"
      
      if connection.table_exists?(table_name)
        begin
          count = connection.execute("SELECT COUNT(*) FROM #{table_name} WHERE hospital_id = #{hospital.id}").first['count']
          stats[category] = {
            table_name: table_name,
            record_count: count.to_i,
            status: count.to_i > 0 ? 'has_data' : 'no_data'
          }
        rescue => e
          stats[category] = {
            table_name: table_name,
            record_count: 0,
            status: 'error',
            error: e.message
          }
        end
      else
        stats[category] = {
          table_name: table_name,
          record_count: 0,
          status: 'table_not_exists'
        }
      end
    end
    
    stats
  end
end
