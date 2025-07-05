class ReportSchedulerController < ApplicationController
  before_action :set_report_schedule, only: [:show, :edit, :update, :destroy, :activate, :deactivate, :execute_now]
  load_and_authorize_resource :report_schedule, except: [:execute_now, :download_report]

  def index
    authorize! :read, ReportSchedule

    @report_schedules = current_hospital.report_schedules
                                       .includes(:user, :report_executions)
                                       .order(created_at: :desc)
                                       .page(params[:page])
                                       .per(20)

    # 필터링
    @report_schedules = @report_schedules.where(status: params[:status]) if params[:status].present?
    @report_schedules = @report_schedules.by_frequency(params[:frequency]) if params[:frequency].present?

    # 리포트 통계
    @report_stats = {
      total: current_hospital.report_schedules.count,
      active: current_hospital.report_schedules.active.count,
      inactive: current_hospital.report_schedules.inactive.count,
      due_for_execution: current_hospital.report_schedules.due_for_execution.count
    }

    # 최근 실행 결과
    @recent_executions = current_hospital.report_schedules
                                        .joins(:report_executions)
                                        .includes(:report_executions)
                                        .merge(ReportExecution.recent)
                                        .limit(10)
  end

  def show
    authorize! :read, @report_schedule

    @executions = @report_schedule.report_executions
                                 .order(created_at: :desc)
                                 .page(params[:page])
                                 .per(20)

    @execution_stats = {
      total: @report_schedule.execution_count,
      success_rate: @report_schedule.success_rate,
      last_execution: @report_schedule.last_execution,
      last_successful: @report_schedule.last_successful_execution
    }
  end

  def new
    authorize! :create, ReportSchedule

    @report_schedule = current_hospital.report_schedules.build
    @available_analyses = get_available_analyses
    @report_templates = get_report_templates
  end

  def create
    authorize! :create, ReportSchedule

    @report_schedule = current_hospital.report_schedules.build(report_schedule_params)
    @report_schedule.user = current_user

    if @report_schedule.save
      redirect_to @report_schedule, notice: '리포트 스케줄이 생성되었습니다.'
    else
      @available_analyses = get_available_analyses
      @report_templates = get_report_templates
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @report_schedule

    @available_analyses = get_available_analyses
    @report_templates = get_report_templates
  end

  def update
    authorize! :update, @report_schedule

    if @report_schedule.update(report_schedule_params)
      redirect_to @report_schedule, notice: '리포트 스케줄이 수정되었습니다.'
    else
      @available_analyses = get_available_analyses
      @report_templates = get_report_templates
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @report_schedule

    @report_schedule.destroy
    redirect_to report_scheduler_index_path, notice: '리포트 스케줄이 삭제되었습니다.'
  end

  def activate
    authorize! :update, @report_schedule

    @report_schedule.activate!
    redirect_to @report_schedule, notice: '리포트 스케줄이 활성화되었습니다.'
  end

  def deactivate
    authorize! :update, @report_schedule

    @report_schedule.deactivate!
    redirect_to @report_schedule, notice: '리포트 스케줄이 비활성화되었습니다.'
  end

  def execute_now
    authorize! :update, @report_schedule

    begin
      @report_schedule.execute_now!
      render json: {
        success: true,
        message: '리포트 생성이 시작되었습니다.'
      }
    rescue => e
      Rails.logger.error("Report execution error: #{e.message}")
      render json: {
        success: false,
        message: "리포트 생성 중 오류가 발생했습니다: #{e.message}"
      }
    end
  end

  def download_report
    execution = ReportExecution.find(params[:execution_id])
    report_schedule = execution.report_schedule

    authorize! :read, report_schedule

    if execution.file_exists?
      send_file execution.file_path,
                filename: "#{report_schedule.name}_#{execution.created_at.strftime('%Y%m%d_%H%M')}.#{report_schedule.format}",
                type: get_content_type(report_schedule.format),
                disposition: 'attachment'
    else
      redirect_to report_schedule, alert: '리포트 파일을 찾을 수 없습니다.'
    end
  end

  private

  def set_report_schedule
    @report_schedule = current_hospital.report_schedules.find(params[:id])
  end

  def report_schedule_params
    params.require(:report_schedule).permit(
      :name, :description, :frequency, :format, :status,
      :report_config, :parameters, recipients: []
    )
  end

  def get_available_analyses
    current_hospital.analysis_results
                   .includes(:user)
                   .order(created_at: :desc)
                   .limit(50)
                   .map do |analysis|
      {
        id: analysis.id,
        name: analysis.description.presence || "분석 ##{analysis.id}",
        type: analysis.analysis_type,
        user: analysis.user.name,
        created_at: analysis.created_at
      }
    end
  end

  def get_report_templates
    [
      {
        id: 'dashboard_summary',
        name: '대시보드 요약',
        description: '주요 KPI와 트렌드를 포함한 요약 리포트',
        sections: ['kpi_summary', 'trend_charts', 'department_performance']
      },
      {
        id: 'financial_report',
        name: '재무 리포트',
        description: '수익, 비용, 예산 분석 리포트',
        sections: ['revenue_analysis', 'cost_analysis', 'budget_variance']
      },
      {
        id: 'operational_report',
        name: '운영 리포트',
        description: '병상 가동률, 직원 효율성 등 운영 지표 리포트',
        sections: ['bed_occupancy', 'staff_efficiency', 'patient_flow']
      },
      {
        id: 'quality_report',
        name: '품질 리포트',
        description: '환자 만족도, 의료 품질 지표 리포트',
        sections: ['patient_satisfaction', 'quality_indicators', 'outcome_metrics']
      },
      {
        id: 'custom_report',
        name: '사용자 정의 리포트',
        description: '선택한 분석 결과를 포함한 맞춤형 리포트',
        sections: ['selected_analyses']
      }
    ]
  end

  def get_content_type(format)
    case format
    when 'pdf'
      'application/pdf'
    when 'excel'
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when 'html'
      'text/html'
    else
      'application/octet-stream'
    end
  end
end
