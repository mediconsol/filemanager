class ReportExecutionJob < ApplicationJob
  queue_as :reports

  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform(report_schedule)
    Rails.logger.info("[ReportExecutionJob] Starting report execution for schedule: #{report_schedule.id}")

    # 실행 기록 생성
    execution = report_schedule.report_executions.create!(status: 'pending')

    begin
      # 실행 시작
      execution.start!

      # 리포트 생성
      generator = Report::GeneratorService.new(report_schedule)
      result = generator.generate

      if result[:success]
        # 성공 처리
        execution.complete!(result[:file_path], result[:file_size])

        # 이메일 발송
        send_report_email(report_schedule, execution)

        # 다음 실행 시간 업데이트
        report_schedule.update_next_run_at!

        Rails.logger.info("[ReportExecutionJob] Report execution completed successfully")
      else
        # 실패 처리
        execution.fail!(result[:error])
        Rails.logger.error("[ReportExecutionJob] Report generation failed: #{result[:error]}")
      end

    rescue => e
      # 예외 처리
      execution.fail!(e.message) if execution.present?
      Rails.logger.error("[ReportExecutionJob] Report execution failed: #{e.message}")
      raise e
    end
  end

  private

  def send_report_email(report_schedule, execution)
    return unless execution.file_exists?

    recipients = report_schedule.recipient_emails
    return if recipients.empty?

    Rails.logger.info("[ReportExecutionJob] Sending report email to #{recipients.count} recipients")

    recipients.each do |email|
      begin
        ReportMailer.report_ready(report_schedule, execution, email).deliver_now
      rescue => e
        Rails.logger.error("[ReportExecutionJob] Failed to send email to #{email}: #{e.message}")
      end
    end
  end
end
