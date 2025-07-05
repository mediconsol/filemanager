class ReportMailer < ApplicationMailer
  default from: 'noreply@hospital-analytics.com'

  def report_ready(report_schedule, execution, recipient_email)
    @report_schedule = report_schedule
    @execution = execution
    @hospital = report_schedule.hospital
    @recipient_email = recipient_email

    # 첨부파일 추가
    if execution.file_exists?
      filename = "#{report_schedule.name}_#{execution.created_at.strftime('%Y%m%d_%H%M')}.#{report_schedule.format}"
      attachments[filename] = File.read(execution.file_path)
    end

    mail(
      to: recipient_email,
      subject: "[#{@hospital.name}] #{@report_schedule.name} - #{execution.created_at.strftime('%Y년 %m월 %d일')}"
    )
  end
end
