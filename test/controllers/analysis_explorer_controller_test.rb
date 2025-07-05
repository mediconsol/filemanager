require "test_helper"

class AnalysisExplorerControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get analysis_explorer_index_url
    assert_response :success
  end

  test "should get show" do
    get analysis_explorer_show_url
    assert_response :success
  end
end
