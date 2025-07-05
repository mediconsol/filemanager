require "test_helper"

class ReportMailerTest < ActionMailer::TestCase
  test "report_ready" do
    mail = ReportMailer.report_ready
    assert_equal "Report ready", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
