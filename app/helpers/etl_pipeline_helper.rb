module EtlPipelineHelper
  def determine_etl_status(etl_jobs)
    return 'none' if etl_jobs.empty?

    statuses = etl_jobs.pluck(:status).uniq

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

  def calculate_etl_progress(etl_jobs)
    return 0 if etl_jobs.empty?

    total_progress = etl_jobs.sum { |job| job.processing_stats&.dig('progress_percentage') || 0 }
    (total_progress / etl_jobs.count).round(1)
  end

  def etl_status_badge(status)
    case status
    when 'completed'
      content_tag :span, class: "badge bg-success" do
        content_tag(:i, '', class: "fas fa-check me-1") + "완료"
      end
    when 'running'
      content_tag :span, class: "badge bg-warning" do
        content_tag(:i, '', class: "fas fa-spinner fa-spin me-1") + "실행중"
      end
    when 'failed'
      content_tag :span, class: "badge bg-danger" do
        content_tag(:i, '', class: "fas fa-times me-1") + "실패"
      end
    when 'pending'
      content_tag :span, class: "badge bg-secondary" do
        content_tag(:i, '', class: "fas fa-clock me-1") + "대기"
      end
    else
      content_tag :span, class: "badge bg-light text-dark" do
        content_tag(:i, '', class: "fas fa-question me-1") + "미실행"
      end
    end
  end

  def job_type_icon(job_type)
    case job_type
    when 'extract'
      'fas fa-download'
    when 'transform'
      'fas fa-exchange-alt'
    when 'load'
      'fas fa-upload'
    when 'full_etl'
      'fas fa-cogs'
    else
      'fas fa-question'
    end
  end

  def format_duration(seconds)
    return '-' unless seconds.present?

    if seconds < 60
      "#{seconds.to_i}초"
    elsif seconds < 3600
      minutes = seconds / 60
      "#{minutes.to_i}분 #{(seconds % 60).to_i}초"
    else
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      "#{hours.to_i}시간 #{minutes.to_i}분"
    end
  end

  def processing_stats_summary(stats)
    return "통계 없음" unless stats.present?

    total = stats['total_rows'] || 0
    processed = stats['processed_rows'] || 0
    errors = stats['error_rows'] || 0

    "#{processed}/#{total} 행 처리 (오류: #{errors})"
  end
end
