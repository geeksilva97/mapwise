require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "show renders settings page" do
    get settings_path
    assert_response :success
    assert_select "h1", "Settings"
  end

  test "show requires authentication" do
    sign_out
    get settings_path
    assert_redirected_to new_session_path
  end

  test "update changes user name" do
    patch settings_path, params: { user: { name: "New Name" } }
    assert_redirected_to settings_path
    assert_equal "New Name", @user.reload.name
  end

  test "update changes user email" do
    patch settings_path, params: { user: { email_address: "new@example.com" } }
    assert_redirected_to settings_path
    assert_equal "new@example.com", @user.reload.email_address
  end

  test "update with invalid params re-renders" do
    patch settings_path, params: { user: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "api key remove button uses confirm dialog" do
    get settings_path
    assert_response :success

    assert_select "button[data-action='click->confirm-dialog#open'][data-confirm-form='#delete_api_key']"
    assert_select "form#delete_api_key[class='hidden']"
  end
end
