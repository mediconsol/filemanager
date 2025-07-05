require "test_helper"

class EtlPipelineControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get etl_pipeline_index_url
    assert_response :success
  end

  test "should get show" do
    get etl_pipeline_show_url
    assert_response :success
  end

  test "should get create" do
    get etl_pipeline_create_url
    assert_response :success
  end

  test "should get start_pipeline" do
    get etl_pipeline_start_pipeline_url
    assert_response :success
  end

  test "should get retry_job" do
    get etl_pipeline_retry_job_url
    assert_response :success
  end

  test "should get cancel_jobs" do
    get etl_pipeline_cancel_jobs_url
    assert_response :success
  end

  test "should get status" do
    get etl_pipeline_status_url
    assert_response :success
  end
end
