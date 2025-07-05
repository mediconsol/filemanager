class DashboardController < ApplicationController
  def index
    render plain: "Hospital Management System - Dashboard is working! 🏥"
  end

  private

  def calculate_kpis(hospital)
    # 실제 데이터가 없으므로 샘플 데이터와 실제 시스템 데이터를 조합
    total_uploads = hospital.data_uploads.count
    completed_uploads = hospital.data_uploads.completed.count
    total_users = hospital.users.active.count
    total_analyses = hospital.analysis_results.count

    # 업로드 성공률 계산
    upload_success_rate = total_uploads > 0 ? (completed_uploads.to_f / total_uploads * 100).round(1) : 0

    # 사용자 활동률 (최근 30일 내 로그인한 사용자)
    active_users = hospital.users.where('last_login_at > ?', 30.days.ago).count
    user_activity_rate = total_users > 0 ? (active_users.to_f / total_users * 100).round(1) : 0

    {
      total_revenue: 1_250_000_000 + (total_uploads * 50_000_000), # 업로드당 가상 수익 추가
      patient_satisfaction: 92.5,
      bed_occupancy: 85.3,
      average_los: 4.2,
      upload_success_rate: upload_success_rate,
      user_activity_rate: user_activity_rate,
      total_uploads: total_uploads,
      total_analyses: total_analyses,
      total_users: total_users
    }
  end

  def calculate_revenue_trend(hospital)
    # 월별 업로드 수를 기반으로 한 가상 수익 트렌드
    base_revenue = 980_000_000
    (1..6).map do |month|
      month_uploads = hospital.data_uploads.where(
        created_at: month.months.ago.beginning_of_month..month.months.ago.end_of_month
      ).count

      {
        month: "#{7-month}월",
        revenue: base_revenue + (month * 70_000_000) + (month_uploads * 30_000_000)
      }
    end.reverse
  end

  def calculate_department_performance(hospital)
    # 사용자 부서별 성과 (실제 부서 데이터 + 가상 성과)
    departments = hospital.users.where.not(department: [nil, '']).group(:department).count

    departments.map do |dept, user_count|
      base_revenue = user_count * 150_000_000
      base_patients = user_count * 200

      {
        department: dept,
        revenue: base_revenue + rand(50_000_000..200_000_000),
        patients: base_patients + rand(100..500),
        user_count: user_count
      }
    end.sort_by { |d| -d[:revenue] }
  end

  def calculate_upload_statistics(hospital)
    uploads_by_status = hospital.data_uploads.group(:status).count
    uploads_by_category = hospital.data_uploads.where.not(data_category: [nil, '']).group(:data_category).count

    {
      by_status: uploads_by_status,
      by_category: uploads_by_category,
      total: hospital.data_uploads.count
    }
  end

  def calculate_user_activity(hospital)
    # 최근 7일간 사용자 활동
    (0..6).map do |days_ago|
      date = days_ago.days.ago.to_date
      active_count = hospital.users.where(
        last_login_at: date.beginning_of_day..date.end_of_day
      ).count

      {
        date: date.strftime('%m/%d'),
        active_users: active_count
      }
    end.reverse
  end
end
