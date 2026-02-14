require "test_helper"

class EmbedsControllerTest < ActionDispatch::IntegrationTest
  test "show renders public map with customer api key" do
    map = maps(:public_map)
    # public_map belongs to user :one, who has api_keys(:one)
    get embed_path(token: map.embed_token)
    assert_response :success
    assert_select "#map-canvas"
  end

  test "show returns 404 for private map" do
    map = maps(:one) # private
    get embed_path(token: map.embed_token)
    assert_response :not_found
  end

  test "show returns 404 for invalid token" do
    get embed_path(token: "nonexistent_token_xyz")
    assert_response :not_found
  end

  test "show returns not configured when owner has no api key" do
    # Create a public map for user two, then remove their api keys
    user = users(:two)
    user.api_keys.destroy_all
    map = maps(:two)
    map.update!(public: true)

    get embed_path(token: map.embed_token)
    assert_response :service_unavailable
    assert_select "h1", /Embedding Not Configured/
  end

  test "does not require authentication" do
    # No sign_in_as call — should still work
    map = maps(:public_map)
    get embed_path(token: map.embed_token)
    assert_response :success
  end

  test "uses embed layout without nav" do
    map = maps(:public_map)
    get embed_path(token: map.embed_token)
    assert_response :success
    # Should not have the main application layout navigation
    assert_select "header", false
  end

  test "embed renders search overlay when search enabled" do
    map = maps(:public_map)
    assert map.search_enabled?
    get embed_path(token: map.embed_token)
    assert_response :success
    assert_select "[data-controller='map-search']"
  end

  test "embed hides search overlay when search disabled" do
    map = maps(:public_map)
    map.update!(search_enabled: false)
    get embed_path(token: map.embed_token)
    assert_response :success
    assert_select "[data-controller='map-search']", count: 0
  end
end
