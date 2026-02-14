require "test_helper"

class MapStylesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index returns system presets and user styles" do
    get map_styles_path
    assert_response :success
  end

  test "index requires authentication" do
    sign_out
    get map_styles_path
    assert_redirected_to new_session_path
  end

  test "create saves user style" do
    assert_difference("MapStyle.count") do
      post map_styles_path, params: {
        map_style: { name: "My New Style", style_json: '[{"test": true}]' }
      }
    end

    assert_redirected_to map_styles_path

    style = MapStyle.last
    assert_equal "My New Style", style.name
    assert_equal @user, style.user
    assert_not style.system_default?
  end

  test "create with invalid params re-renders" do
    assert_no_difference("MapStyle.count") do
      post map_styles_path, params: {
        map_style: { name: "", style_json: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "destroy removes user style" do
    custom_style = map_styles(:user_one_custom)
    assert_difference("MapStyle.count", -1) do
      delete map_style_path(custom_style)
    end

    assert_redirected_to map_styles_path
  end

  test "user cannot delete system presets" do
    system_style = map_styles(:system_default)
    assert_no_difference("MapStyle.count") do
      delete map_style_path(system_style)
    end

    assert_redirected_to map_styles_path
    follow_redirect!
    assert_select "#alert", /Cannot delete system presets/
  end

  test "user cannot delete other user's styles" do
    other_style = map_styles(:user_two_custom)
    assert_no_difference("MapStyle.count") do
      delete map_style_path(other_style)
    end

    assert_response :not_found
  end

  test "cross-user deletion attempt returns 404" do
    sign_in_as(users(:two))
    user_one_style = map_styles(:user_one_custom)

    assert_no_difference("MapStyle.count") do
      delete map_style_path(user_one_style)
    end

    assert_response :not_found
  end
end
