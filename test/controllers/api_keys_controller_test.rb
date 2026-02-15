require "test_helper"

class ApiKeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index lists user's api keys" do
    get api_keys_path
    assert_response :success
    assert_select "p.font-medium", api_keys(:one).label
  end

  test "index requires authentication" do
    sign_out
    get api_keys_path
    assert_redirected_to new_session_path
  end

  test "create saves encrypted api key" do
    assert_difference("ApiKey.count") do
      post api_keys_path, params: {
        api_key: { google_maps_key: "AIzaSyBrandNewKey123", label: "Test Key" }
      }
    end

    assert_redirected_to api_keys_path

    key = ApiKey.last
    assert_equal "AIzaSyBrandNewKey123", key.google_maps_key
    assert_equal "Test Key", key.label
    assert_equal @user, key.user
  end

  test "create with invalid params re-renders form" do
    assert_no_difference("ApiKey.count") do
      post api_keys_path, params: {
        api_key: { google_maps_key: "", label: "Bad" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "update changes api key" do
    api_key = api_keys(:one)
    patch api_key_path(api_key), params: {
      api_key: { google_maps_key: "AIzaSyUpdatedKey456" }
    }

    assert_redirected_to api_keys_path
    api_key.reload
    assert_equal "AIzaSyUpdatedKey456", api_key.google_maps_key
  end

  test "destroy removes api key" do
    api_key = api_keys(:one)
    assert_difference("ApiKey.count", -1) do
      delete api_key_path(api_key)
    end

    assert_redirected_to api_keys_path
  end

  test "user cannot access other user's api key" do
    other_key = api_keys(:two)
    patch api_key_path(other_key), params: {
      api_key: { google_maps_key: "stolen" }
    }
    assert_response :not_found
  end

  test "user cannot delete other user's api key" do
    other_key = api_keys(:two)
    assert_no_difference("ApiKey.count") do
      delete api_key_path(other_key)
    end
    assert_response :not_found
  end

  test "update with invalid params re-renders form" do
    api_key = api_keys(:one)
    patch api_key_path(api_key), params: {
      api_key: { google_maps_key: "" }
    }
    assert_response :unprocessable_entity
  end

  test "update label only" do
    api_key = api_keys(:one)
    patch api_key_path(api_key), params: {
      api_key: { label: "Renamed Key" }
    }
    assert_redirected_to api_keys_path
    assert_equal "Renamed Key", api_key.reload.label
  end
end
