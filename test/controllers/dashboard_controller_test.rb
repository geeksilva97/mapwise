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

  test "dashboard renders global confirm dialog" do
    get dashboard_path
    assert_response :success
    assert_select "dialog[data-confirm-dialog-target='dialog']"
    assert_select "[data-confirm-dialog-target='title']"
    assert_select "[data-confirm-dialog-target='message']"
  end

  test "map cards have delete button wired to confirm dialog" do
    get dashboard_path
    assert_response :success

    @user.maps.each do |map|
      assert_select "button[data-action='click->confirm-dialog#open'][data-confirm-form='#delete_map_#{map.id}']"
      assert_select "form#delete_map_#{map.id}[class='hidden']"
    end
  end
end
