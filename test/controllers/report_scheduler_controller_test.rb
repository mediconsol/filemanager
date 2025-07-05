require "test_helper"

class ReportSchedulerControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get report_scheduler_index_url
    assert_response :success
  end

  test "should get new" do
    get report_scheduler_new_url
    assert_response :success
  end

  test "should get create" do
    get report_scheduler_create_url
    assert_response :success
  end

  test "should get show" do
    get report_scheduler_show_url
    assert_response :success
  end

  test "should get edit" do
    get report_scheduler_edit_url
    assert_response :success
  end

  test "should get update" do
    get report_scheduler_update_url
    assert_response :success
  end
end
