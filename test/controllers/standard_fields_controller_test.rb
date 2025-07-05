require "test_helper"

class StandardFieldsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get standard_fields_index_url
    assert_response :success
  end

  test "should get show" do
    get standard_fields_show_url
    assert_response :success
  end

  test "should get new" do
    get standard_fields_new_url
    assert_response :success
  end

  test "should get create" do
    get standard_fields_create_url
    assert_response :success
  end

  test "should get edit" do
    get standard_fields_edit_url
    assert_response :success
  end

  test "should get update" do
    get standard_fields_update_url
    assert_response :success
  end

  test "should get destroy" do
    get standard_fields_destroy_url
    assert_response :success
  end
end
