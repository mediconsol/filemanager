require "test_helper"

class DataUploadsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get data_uploads_index_url
    assert_response :success
  end

  test "should get new" do
    get data_uploads_new_url
    assert_response :success
  end

  test "should get create" do
    get data_uploads_create_url
    assert_response :success
  end

  test "should get show" do
    get data_uploads_show_url
    assert_response :success
  end
end
