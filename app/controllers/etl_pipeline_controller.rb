class EtlPipelineController < ApplicationController
  before_action :set_data_upload, only: [:show, :start_pipeline, :cancel_jobs, :status]
  before_action :set_etl_job, only: [:retry_job]
  load_and_authorize_resource :etl_job, except: [:index, :show, :start_pipeline, :cancel_jobs, :status]

  def index
    authorize! :read, EtlJob

    @data_uploads = current_hospital.data_uploads
                                   .includes(:etl_jobs, :user)
                                   .where(status: ['completed', 'processing'])
                                   .order(created_at: :desc)
                                   .page(params[:page])
                                   .per(20)

    # ETL 통계
    @etl_stats = {
      total_pipelines: current_hospital.etl_jobs.select(:data_upload_id).distinct.count,
      running_jobs: current_hospital.etl_jobs.running.count,
      completed_jobs: current_hospital.etl_jobs.completed.count,
      failed_jobs: current_hospital.etl_jobs.failed.count
    }
  end

  def show
    authorize! :read, EtlJob

    @pipeline_service = ::Etl::PipelineService.new(@data_upload, current_user)
    @pipeline_status = @pipeline_service.get_pipeline_status
    @etl_jobs = @data_upload.etl_jobs.order(:created_at)
    @prerequisites = @pipeline_service.validate_prerequisites
    @time_estimate = @pipeline_service.estimate_processing_time
  end

  def start_pipeline
    authorize! :create, EtlJob

    begin
      pipeline_service = ::Etl::PipelineService.new(@data_upload, current_user)

      # 전제 조건 검증
      prerequisites = pipeline_service.validate_prerequisites
      if prerequisites.any?
        render json: {
          success: false,
          message: "전제 조건을 만족하지 않습니다: #{prerequisites.join(', ')}"
        }
        return
      end

      # 이미 실행 중인 작업이 있는지 확인
      if @data_upload.etl_jobs.running.any?
        render json: {
          success: false,
          message: "이미 실행 중인 ETL 작업이 있습니다."
        }
        return
      end

      # ETL 파이프라인 시작
      result = pipeline_service.execute_full_pipeline

      render json: result

    rescue => e
      Rails.logger.error("ETL Pipeline start error: #{e.message}")
      render json: {
        success: false,
        message: "ETL 파이프라인 시작 중 오류가 발생했습니다: #{e.message}"
      }
    end
  end

  def retry_job
    authorize! :update, @etl_job

    begin
      unless @etl_job.can_restart?
        render json: {
          success: false,
          message: "이 작업은 재시작할 수 없습니다. 현재 상태: #{@etl_job.status}"
        }
        return
      end

      pipeline_service = ::Etl::PipelineService.new(@etl_job.data_upload, current_user)
      pipeline_service.retry_failed_job(@etl_job)

      render json: {
        success: true,
        message: "작업이 재시작되었습니다.",
        job_id: @etl_job.id
      }

    rescue => e
      Rails.logger.error("ETL Job retry error: #{e.message}")
      render json: {
        success: false,
        message: "작업 재시작 중 오류가 발생했습니다: #{e.message}"
      }
    end
  end

  def cancel_jobs
    authorize! :update, EtlJob

    begin
      pipeline_service = ::Etl::PipelineService.new(@data_upload, current_user)
      result = pipeline_service.cancel_running_jobs

      render json: result

    rescue => e
      Rails.logger.error("ETL Jobs cancel error: #{e.message}")
      render json: {
        success: false,
        message: "작업 취소 중 오류가 발생했습니다: #{e.message}"
      }
    end
  end

  def status
    authorize! :read, EtlJob

    begin
      pipeline_service = ::Etl::PipelineService.new(@data_upload, current_user)
      status = pipeline_service.get_pipeline_status

      render json: status

    rescue => e
      Rails.logger.error("ETL Status error: #{e.message}")
      render json: {
        error: "상태 조회 중 오류가 발생했습니다: #{e.message}"
      }
    end
  end

  private

  def set_data_upload
    @data_upload = current_hospital.data_uploads.find(params[:id])
  end

  def set_etl_job
    @etl_job = current_hospital.etl_jobs.find(params[:id])
  end
end
