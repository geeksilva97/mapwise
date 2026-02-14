require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @map = maps(:one)
    sign_in_as(@user)
  end

  test "new renders form" do
    get new_map_path
    assert_response :success
    assert_select "h1", "New Map"
  end

  test "new requires authentication" do
    sign_out
    get new_map_path
    assert_redirected_to new_session_path
  end

  test "create saves map and redirects to edit" do
    assert_difference("Map.count") do
      post maps_path, params: { map: { title: "Road Trip 2026" } }
    end

    map = Map.last
    assert_equal "Road Trip 2026", map.title
    assert_equal @user, map.user
    assert_not_nil map.embed_token
    assert_redirected_to edit_map_path(map)
  end

  test "create with invalid params re-renders form" do
    assert_no_difference("Map.count") do
      post maps_path, params: { map: { title: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "show renders viewer" do
    get map_path(@map)
    assert_response :success
    assert_select "h1", @map.title
    assert_select "#map-canvas"
  end

  test "show requires authentication" do
    sign_out
    get map_path(@map)
    assert_redirected_to new_session_path
  end

  test "edit renders editor" do
    get edit_map_path(@map)
    assert_response :success
    assert_select "#map-canvas"
  end

  test "edit requires authentication and ownership" do
    sign_out
    get edit_map_path(@map)
    assert_redirected_to new_session_path
  end

  test "update saves changes via HTML" do
    patch map_path(@map), params: { map: { title: "Updated Title" } }
    assert_redirected_to edit_map_path(@map)

    @map.reload
    assert_equal "Updated Title", @map.title
  end

  test "update saves changes via JSON" do
    patch map_path(@map),
          params: { map: { center_lat: 40.0, center_lng: -74.0, zoom: 10 } },
          as: :json

    assert_response :ok
    @map.reload
    assert_in_delta 40.0, @map.center_lat, 0.001
    assert_in_delta(-74.0, @map.center_lng, 0.001)
    assert_equal 10, @map.zoom
  end

  test "destroy removes map and redirects" do
    assert_difference("Map.count", -1) do
      delete map_path(@map)
    end

    assert_redirected_to root_path
  end

  test "user cannot access other user's map" do
    other_map = maps(:two)
    get map_path(other_map)
    assert_response :not_found
  end

  test "user cannot edit other user's map" do
    other_map = maps(:two)
    get edit_map_path(other_map)
    assert_response :not_found
  end

  test "user cannot update other user's map" do
    other_map = maps(:two)
    patch map_path(other_map), params: { map: { title: "Hacked" } }
    assert_response :not_found
  end

  test "user cannot delete other user's map" do
    other_map = maps(:two)
    assert_no_difference("Map.count") do
      delete map_path(other_map)
    end
    assert_response :not_found
  end
end
