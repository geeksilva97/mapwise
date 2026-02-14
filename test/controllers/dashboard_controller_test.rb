require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index requires authentication" do
    sign_out
    get dashboard_path
    assert_redirected_to new_session_path
  end

  test "index shows current user's maps" do
    get dashboard_path
    assert_response :success
    assert_select "h1", "My Maps"

    # User one has maps: :one and :public_map
    @user.maps.each do |map|
      assert_select "h3", map.title
    end
  end

  test "index does not show other user's maps" do
    get dashboard_path
    assert_response :success

    other_map = maps(:two)
    assert_select "h3", { text: other_map.title, count: 0 }
  end

  test "index shows maps ordered by updated_at desc" do
    get dashboard_path
    assert_response :success
    assert_select ".grid"
  end

  test "root path renders dashboard when authenticated" do
    get root_path
    assert_response :success
    assert_select "h1", "My Maps"
  end

  test "root path redirects to login when not authenticated" do
    sign_out
    get root_path
    assert_redirected_to new_session_path
  end
end
