require "test_helper"

class AdminCenterControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_center_index_url
    assert_response :success
  end

  test "should get users" do
    get admin_center_users_url
    assert_response :success
  end

  test "should get hospitals" do
    get admin_center_hospitals_url
    assert_response :success
  end

  test "should get system_monitoring" do
    get admin_center_system_monitoring_url
    assert_response :success
  end
end
