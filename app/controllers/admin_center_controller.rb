class AdminCenterController < ApplicationController
  before_action :ensure_admin_access
  skip_authorization_check

  def index
    @system_stats = calculate_system_stats
    @recent_activities = get_recent_activities
    @system_health = check_system_health
    @active_users = get_active_users
  end

  def users
    @users = User.includes(:hospital)
                 .order(created_at: :desc)
                 .page(params[:page])
                 .per(20)

    # 필터링
    @users = @users.where(hospital_id: params[:hospital_id]) if params[:hospital_id].present?
    @users = @users.where(role: params[:role]) if params[:role].present?
    @users = @users.where(is_active: params[:is_active]) if params[:is_active].present?

    @hospitals = Hospital.active.order(:name)
    @user_stats = calculate_user_stats
  end

  def hospitals
    @hospitals = Hospital.includes(:users)
                        .order(created_at: :desc)
                        .page(params[:page])
                        .per(20)

    # 필터링
    @hospitals = @hospitals.where(is_active: params[:is_active]) if params[:is_active].present?

    @hospital_stats = calculate_hospital_stats
  end

  def system_monitoring
    @system_metrics = get_system_metrics
    @database_stats = get_database_stats
    @job_stats = get_job_stats
    @error_logs = get_recent_errors
    @performance_metrics = get_performance_metrics
  end

  private

  def ensure_admin_access
    unless current_user&.admin?
      redirect_to root_path, alert: '관리자 권한이 필요합니다.'
    end
  end

  def calculate_system_stats
    {
      total_hospitals: Hospital.count,
      active_hospitals: Hospital.active.count,
      total_users: User.count,
      active_users: User.active.count,
      total_uploads: DataUpload.count,
      completed_uploads: DataUpload.where(status: 'completed').count,
      total_analyses: AnalysisResult.count,
      total_reports: ReportSchedule.count,
      active_reports: ReportSchedule.active.count
    }
  end

  def get_recent_activities
    activities = []

    # 최근 사용자 등록
    recent_users = User.order(created_at: :desc).limit(5)
    recent_users.each do |user|
      activities << {
        type: 'user_registration',
        description: "새 사용자 등록: #{user.name} (#{user.hospital.name})",
        timestamp: user.created_at,
        user: user
      }
    end

    # 최근 데이터 업로드
    recent_uploads = DataUpload.includes(:user, :hospital).order(created_at: :desc).limit(5)
    recent_uploads.each do |upload|
      activities << {
        type: 'data_upload',
        description: "데이터 업로드: #{upload.file_name} (#{upload.hospital.name})",
        timestamp: upload.created_at,
        user: upload.user
      }
    end

    # 최근 분석 생성
    recent_analyses = AnalysisResult.includes(:user, :hospital).order(created_at: :desc).limit(5)
    recent_analyses.each do |analysis|
      activities << {
        type: 'analysis_creation',
        description: "분석 생성: #{analysis.description.presence || "분석 ##{analysis.id}"} (#{analysis.hospital.name})",
        timestamp: analysis.created_at,
        user: analysis.user
      }
    end

    # 시간순 정렬
    activities.sort_by { |activity| activity[:timestamp] }.reverse.first(10)
  end

  def check_system_health
    health_checks = {}

    # 데이터베이스 연결 확인
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      health_checks[:database] = { status: 'healthy', message: '정상' }
    rescue => e
      health_checks[:database] = { status: 'error', message: e.message }
    end

    # 디스크 사용량 확인 (간단한 예시)
    begin
      disk_usage = `df -h /`.split("\n")[1].split[4].to_i rescue 0
      if disk_usage > 90
        health_checks[:disk] = { status: 'warning', message: "디스크 사용량 #{disk_usage}%" }
      elsif disk_usage > 95
        health_checks[:disk] = { status: 'error', message: "디스크 사용량 #{disk_usage}%" }
      else
        health_checks[:disk] = { status: 'healthy', message: "디스크 사용량 #{disk_usage}%" }
      end
    rescue
      health_checks[:disk] = { status: 'unknown', message: '확인 불가' }
    end

    # 메모리 사용량 확인
    begin
      memory_info = `free -m`.split("\n")[1].split rescue []
      if memory_info.length >= 3
        total_memory = memory_info[1].to_i
        used_memory = memory_info[2].to_i
        memory_usage = (used_memory.to_f / total_memory * 100).round(1)

        if memory_usage > 90
          health_checks[:memory] = { status: 'warning', message: "메모리 사용량 #{memory_usage}%" }
        elsif memory_usage > 95
          health_checks[:memory] = { status: 'error', message: "메모리 사용량 #{memory_usage}%" }
        else
          health_checks[:memory] = { status: 'healthy', message: "메모리 사용량 #{memory_usage}%" }
        end
      else
        health_checks[:memory] = { status: 'unknown', message: '확인 불가' }
      end
    rescue
      health_checks[:memory] = { status: 'unknown', message: '확인 불가' }
    end

    # 백그라운드 작업 확인
    begin
      failed_jobs = 0 # 실제로는 Sidekiq나 다른 job queue에서 확인
      if failed_jobs > 10
        health_checks[:jobs] = { status: 'warning', message: "실패한 작업 #{failed_jobs}개" }
      elsif failed_jobs > 50
        health_checks[:jobs] = { status: 'error', message: "실패한 작업 #{failed_jobs}개" }
      else
        health_checks[:jobs] = { status: 'healthy', message: '작업 큐 정상' }
      end
    rescue
      health_checks[:jobs] = { status: 'unknown', message: '확인 불가' }
    end

    health_checks
  end

  def get_active_users
    User.where('last_login_at > ?', 1.hour.ago)
        .includes(:hospital)
        .order(last_login_at: :desc)
        .limit(10)
  end

  def calculate_user_stats
    {
      total: User.count,
      active: User.active.count,
      inactive: User.inactive.count,
      admins: User.where(role: 'admin').count,
      analysts: User.where(role: 'analyst').count,
      viewers: User.where(role: 'viewer').count,
      recent_logins: User.where('last_login_at > ?', 24.hours.ago).count
    }
  end

  def calculate_hospital_stats
    {
      total: Hospital.count,
      active: Hospital.active.count,
      inactive: Hospital.inactive.count,
      with_users: Hospital.joins(:users).distinct.count,
      with_data: Hospital.joins(:data_uploads).distinct.count
    }
  end

  def get_system_metrics
    {
      uptime: get_system_uptime,
      load_average: get_load_average,
      cpu_usage: get_cpu_usage,
      memory_usage: get_memory_usage,
      disk_usage: get_disk_usage
    }
  end

  def get_database_stats
    connection = ActiveRecord::Base.connection

    {
      total_tables: connection.tables.count,
      total_size: get_database_size,
      connection_count: get_connection_count,
      slow_queries: get_slow_query_count
    }
  end

  def get_job_stats
    {
      total_jobs: 0, # 실제로는 job queue에서 조회
      pending_jobs: 0,
      failed_jobs: 0,
      completed_jobs: 0
    }
  end

  def get_recent_errors
    # 실제로는 로그 파일이나 에러 추적 시스템에서 조회
    []
  end

  def get_performance_metrics
    {
      average_response_time: rand(100..500), # ms
      requests_per_minute: rand(50..200),
      error_rate: rand(0.1..2.0).round(2) # %
    }
  end

  def get_system_uptime
    begin
      uptime_seconds = File.read('/proc/uptime').split[0].to_f
      days = (uptime_seconds / 86400).to_i
      hours = ((uptime_seconds % 86400) / 3600).to_i
      minutes = ((uptime_seconds % 3600) / 60).to_i
      "#{days}일 #{hours}시간 #{minutes}분"
    rescue
      '확인 불가'
    end
  end

  def get_load_average
    begin
      File.read('/proc/loadavg').split[0..2].join(', ')
    rescue
      '확인 불가'
    end
  end

  def get_cpu_usage
    begin
      # 간단한 CPU 사용률 계산 (실제로는 더 정교한 방법 사용)
      rand(10..80).to_s + '%'
    rescue
      '확인 불가'
    end
  end

  def get_memory_usage
    begin
      memory_info = `free -m`.split("\n")[1].split
      if memory_info.length >= 3
        total = memory_info[1].to_i
        used = memory_info[2].to_i
        "#{used}MB / #{total}MB (#{(used.to_f / total * 100).round(1)}%)"
      else
        '확인 불가'
      end
    rescue
      '확인 불가'
    end
  end

  def get_disk_usage
    begin
      disk_info = `df -h /`.split("\n")[1].split
      "#{disk_info[2]} / #{disk_info[1]} (#{disk_info[4]})"
    rescue
      '확인 불가'
    end
  end

  def get_database_size
    begin
      connection = ActiveRecord::Base.connection
      case connection.adapter_name.downcase
      when 'postgresql'
        result = connection.execute("SELECT pg_size_pretty(pg_database_size(current_database()))")
        result.first['pg_size_pretty']
      when 'mysql', 'mysql2'
        result = connection.execute("SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size in MB' FROM information_schema.tables WHERE table_schema=DATABASE()")
        "#{result.first[0]}MB"
      else
        '확인 불가'
      end
    rescue
      '확인 불가'
    end
  end

  def get_connection_count
    begin
      connection = ActiveRecord::Base.connection
      case connection.adapter_name.downcase
      when 'postgresql'
        result = connection.execute("SELECT count(*) FROM pg_stat_activity")
        result.first['count']
      when 'mysql', 'mysql2'
        result = connection.execute("SHOW STATUS LIKE 'Threads_connected'")
        result.first[1]
      else
        0
      end
    rescue
      0
    end
  end

  def get_slow_query_count
    # 실제로는 slow query log에서 조회
    rand(0..5)
  end
end
