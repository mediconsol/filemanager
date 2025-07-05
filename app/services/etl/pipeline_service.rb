class Etl::PipelineService
  attr_reader :data_upload, :hospital, :user

  def initialize(data_upload, user = nil)
    @data_upload = data_upload
    @hospital = data_upload.hospital
    @user = user
  end

  def execute_full_pipeline
    Rails.logger.info("[ETL Pipeline] Starting full ETL pipeline for #{data_upload.file_name}")
    
    begin
      # ETL 작업들 생성
      etl_jobs = EtlJob.create_etl_pipeline(data_upload, user)
      
      # 순차적으로 실행
      execute_extract(etl_jobs[0])
      execute_transform(etl_jobs[1])
      execute_load(etl_jobs[2])
      
      Rails.logger.info("[ETL Pipeline] Full ETL pipeline completed successfully")
      
      {
        success: true,
        message: "ETL 파이프라인이 성공적으로 완료되었습니다.",
        jobs: etl_jobs.map { |job| job_summary(job) }
      }
      
    rescue => e
      Rails.logger.error("[ETL Pipeline] Pipeline failed: #{e.message}")
      
      {
        success: false,
        message: "ETL 파이프라인 실행 중 오류가 발생했습니다: #{e.message}",
        error: e.message
      }
    end
  end

  def execute_extract(etl_job = nil)
    etl_job ||= create_extract_job
    
    Rails.logger.info("[ETL Pipeline] Starting extract phase")
    
    service = Etl::ExtractService.new(etl_job)
    service.execute
    
    etl_job
  end

  def execute_transform(etl_job = nil)
    etl_job ||= create_transform_job
    
    Rails.logger.info("[ETL Pipeline] Starting transform phase")
    
    # 매핑이 있는지 확인
    if data_upload.field_mappings.active.empty?
      raise "No active field mappings found. Please configure field mappings first."
    end
    
    service = Etl::TransformService.new(etl_job)
    service.execute
    
    etl_job
  end

  def execute_load(etl_job = nil)
    etl_job ||= create_load_job
    
    Rails.logger.info("[ETL Pipeline] Starting load phase")
    
    service = Etl::LoadService.new(etl_job)
    service.execute
    
    etl_job
  end

  def retry_failed_job(etl_job)
    Rails.logger.info("[ETL Pipeline] Retrying failed job #{etl_job.id}")
    
    case etl_job.job_type
    when 'extract'
      execute_extract(etl_job)
    when 'transform'
      execute_transform(etl_job)
    when 'load'
      execute_load(etl_job)
    else
      raise "Unknown job type: #{etl_job.job_type}"
    end
  end

  def cancel_running_jobs
    Rails.logger.info("[ETL Pipeline] Cancelling running jobs for #{data_upload.file_name}")
    
    running_jobs = data_upload.etl_jobs.running
    running_jobs.each(&:cancel!)
    
    {
      success: true,
      message: "#{running_jobs.count}개의 실행 중인 작업이 취소되었습니다.",
      cancelled_jobs: running_jobs.count
    }
  end

  def get_pipeline_status
    jobs = data_upload.etl_jobs.order(:created_at)
    
    {
      data_upload_id: data_upload.id,
      file_name: data_upload.file_name,
      overall_status: determine_overall_status(jobs),
      jobs: jobs.map { |job| job_summary(job) },
      progress: calculate_overall_progress(jobs),
      started_at: jobs.minimum(:started_at),
      completed_at: jobs.maximum(:completed_at),
      duration: calculate_total_duration(jobs)
    }
  end

  def cleanup_intermediate_data(keep_days = 7)
    Rails.logger.info("[ETL Pipeline] Cleaning up intermediate data older than #{keep_days} days")
    
    cutoff_date = keep_days.days.ago
    
    # Raw 테이블 정리
    raw_table_name = "raw_#{data_upload.data_category || 'general'}_#{hospital.id}"
    if ActiveRecord::Base.connection.table_exists?(raw_table_name)
      ActiveRecord::Base.connection.execute(
        "DELETE FROM #{raw_table_name} WHERE created_at < '#{cutoff_date.iso8601}'"
      )
    end
    
    # Staging 테이블 정리
    staging_table_name = "staging_#{data_upload.data_category || 'general'}_#{hospital.id}"
    if ActiveRecord::Base.connection.table_exists?(staging_table_name)
      ActiveRecord::Base.connection.execute(
        "DELETE FROM #{staging_table_name} WHERE created_at < '#{cutoff_date.iso8601}'"
      )
    end
    
    Rails.logger.info("[ETL Pipeline] Cleanup completed")
  end

  def validate_prerequisites
    errors = []
    
    # 파일 존재 확인
    unless File.exist?(data_upload.file_path)
      errors << "Source file not found: #{data_upload.file_path}"
    end
    
    # 데이터 업로드 상태 확인
    unless %w[completed processing].include?(data_upload.status)
      errors << "Data upload must be completed or processing. Current status: #{data_upload.status}"
    end
    
    # 병원 정보 확인
    unless hospital.present?
      errors << "Hospital information is missing"
    end
    
    errors
  end

  def estimate_processing_time
    file_size_mb = data_upload.file_size_mb
    row_count = data_upload.total_rows || 0
    
    # 간단한 추정 공식 (실제 환경에서는 더 정교한 모델 사용)
    base_time = 30 # 기본 30초
    size_factor = file_size_mb * 2 # MB당 2초
    row_factor = row_count / 1000 * 5 # 1000행당 5초
    
    estimated_seconds = base_time + size_factor + row_factor
    
    {
      estimated_seconds: estimated_seconds.to_i,
      estimated_minutes: (estimated_seconds / 60.0).round(1),
      factors: {
        base_time: base_time,
        file_size_impact: size_factor,
        row_count_impact: row_factor
      }
    }
  end

  private

  def create_extract_job
    hospital.etl_jobs.create!(
      data_upload: data_upload,
      user: user,
      job_type: 'extract',
      stage: 'raw',
      status: 'pending',
      job_config: { source_file: data_upload.file_path }
    )
  end

  def create_transform_job
    hospital.etl_jobs.create!(
      data_upload: data_upload,
      user: user,
      job_type: 'transform',
      stage: 'staging',
      status: 'pending',
      job_config: { apply_mappings: true, validate_data: true }
    )
  end

  def create_load_job
    hospital.etl_jobs.create!(
      data_upload: data_upload,
      user: user,
      job_type: 'load',
      stage: 'core',
      status: 'pending',
      job_config: { target_tables: determine_target_tables }
    )
  end

  def determine_target_tables
    case data_upload.data_category
    when 'financial'
      ['core_financial_data']
    when 'operational'
      ['core_operational_data']
    when 'quality'
      ['core_quality_data']
    when 'patient'
      ['core_patient_data']
    else
      ['core_general_data']
    end
  end

  def job_summary(job)
    {
      id: job.id,
      job_type: job.job_type,
      stage: job.stage,
      status: job.status,
      progress_percentage: job.progress_percentage,
      duration: job.duration_formatted,
      error_message: job.error_message,
      started_at: job.started_at,
      completed_at: job.completed_at,
      processing_stats: job.processing_stats
    }
  end

  def determine_overall_status(jobs)
    return 'pending' if jobs.empty?
    
    statuses = jobs.pluck(:status).uniq
    
    if statuses.include?('failed')
      'failed'
    elsif statuses.include?('running')
      'running'
    elsif statuses.include?('pending')
      'pending'
    elsif statuses.all? { |s| s == 'completed' }
      'completed'
    else
      'mixed'
    end
  end

  def calculate_overall_progress(jobs)
    return 0 if jobs.empty?
    
    total_progress = jobs.sum(&:progress_percentage)
    (total_progress / jobs.count).round(1)
  end

  def calculate_total_duration(jobs)
    return nil if jobs.empty?
    
    start_time = jobs.minimum(:started_at)
    end_time = jobs.maximum(:completed_at) || Time.current
    
    return nil unless start_time
    
    duration = end_time - start_time
    
    if duration < 60
      "#{duration.to_i}초"
    elsif duration < 3600
      "#{(duration / 60).to_i}분 #{(duration % 60).to_i}초"
    else
      hours = (duration / 3600).to_i
      minutes = ((duration % 3600) / 60).to_i
      "#{hours}시간 #{minutes}분"
    end
  end
end
