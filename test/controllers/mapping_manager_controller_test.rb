require "test_helper"

class MappingManagerControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get mapping_manager_index_url
    assert_response :success
  end

  test "should get show" do
    get mapping_manager_show_url
    assert_response :success
  end

  test "should get edit" do
    get mapping_manager_edit_url
    assert_response :success
  end

  test "should get update" do
    get mapping_manager_update_url
    assert_response :success
  end
end
