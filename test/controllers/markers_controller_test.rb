require "test_helper"

class MarkersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @map = maps(:one)
    @marker = markers(:one)
    sign_in_as(@user)
  end

  test "create with valid params via turbo_stream" do
    assert_difference("Marker.count") do
      post map_markers_path(@map),
           params: { marker: { lat: 41.8781, lng: -87.6298, title: "Chicago" } },
           as: :turbo_stream
    end

    assert_response :success

    marker = Marker.last
    assert_equal "Chicago", marker.title
    assert_in_delta 41.8781, marker.lat, 0.001
    assert_equal @map, marker.map
  end

  test "create with valid params via json" do
    assert_difference("Marker.count") do
      post map_markers_path(@map),
           params: { marker: { lat: 41.0, lng: -87.0 } },
           as: :json
    end

    assert_response :success
  end

  test "create with missing lat returns error" do
    assert_no_difference("Marker.count") do
      post map_markers_path(@map),
           params: { marker: { lng: -74.0 } },
           as: :json
    end

    assert_response :unprocessable_entity
  end

  test "update changes marker attributes via turbo_stream" do
    patch map_marker_path(@map, @marker),
          params: { marker: { title: "Updated NYC", color: "#0000FF" } },
          as: :turbo_stream

    assert_response :success
    @marker.reload
    assert_equal "Updated NYC", @marker.title
    assert_equal "#0000FF", @marker.color
  end

  test "update marker position via json (drag-end)" do
    patch map_marker_path(@map, @marker),
          params: { marker: { lat: 42.0, lng: -75.0 } },
          as: :json

    assert_response :success
    @marker.reload
    assert_in_delta 42.0, @marker.lat, 0.001
    assert_in_delta(-75.0, @marker.lng, 0.001)
  end

  test "destroy removes marker via turbo_stream" do
    assert_difference("Marker.count", -1) do
      delete map_marker_path(@map, @marker), as: :turbo_stream
    end

    assert_response :success
  end

  test "destroy removes marker via json" do
    assert_difference("Marker.count", -1) do
      delete map_marker_path(@map, @marker), as: :json
    end

    assert_response :no_content
  end

  test "markers are scoped to parent map" do
    other_marker = markers(:on_other_map)
    patch map_marker_path(@map, other_marker),
          params: { marker: { title: "Hacked" } },
          as: :json

    assert_response :not_found
  end

  test "user cannot CRUD markers on other user's maps" do
    other_map = maps(:two)
    post map_markers_path(other_map),
         params: { marker: { lat: 40.0, lng: -74.0 } },
         as: :json

    assert_response :not_found
  end

  test "edit loads marker form in turbo frame" do
    get edit_map_marker_path(@map, @marker)
    assert_response :success
  end

  test "create requires authentication" do
    sign_out
    post map_markers_path(@map),
         params: { marker: { lat: 40.0, lng: -74.0 } },
         as: :json

    assert_redirected_to new_session_path
  end

  test "create with custom_info_html" do
    post map_markers_path(@map),
         params: { marker: { lat: 41.0, lng: -87.0, custom_info_html: "<p>Custom</p>" } },
         as: :json

    assert_response :success
    marker = Marker.last
    assert_equal "<p>Custom</p>", marker.custom_info_html
  end

  test "update with custom_info_html" do
    patch map_marker_path(@map, @marker),
          params: { marker: { custom_info_html: "<strong>Bold</strong>" } },
          as: :json

    assert_response :success
    @marker.reload
    assert_equal "<strong>Bold</strong>", @marker.custom_info_html
  end

  test "ungroup removes marker from group and resets color" do
    group = marker_groups(:restaurants)
    @marker.update!(marker_group_id: group.id, color: group.color)

    patch ungroup_map_marker_path(@map, @marker), as: :json

    assert_response :success
    @marker.reload
    assert_nil @marker.marker_group_id
    assert_equal "#FF0000", @marker.color
  end

  test "ungroup on other user's map returns not found" do
    other_map = maps(:two)
    other_marker = markers(:on_other_map)

    patch ungroup_map_marker_path(other_map, other_marker), as: :json

    assert_response :not_found
  end

  test "create multiple markers in sequence" do
    assert_difference("Marker.count", 3) do
      3.times do |i|
        post map_markers_path(@map),
             params: { marker: { lat: 40.0 + i, lng: -74.0 + i, title: "Marker #{i}" } },
             as: :json
        assert_response :success
      end
    end
  end

  test "create with marker_group_id" do
    group = marker_groups(:restaurants)
    post map_markers_path(@map),
         params: { marker: { lat: 41.0, lng: -87.0, marker_group_id: group.id } },
         as: :json

    assert_response :success
    marker = Marker.last
    assert_equal group.id, marker.marker_group_id
  end

  test "create with invalid params via json returns errors" do
    post map_markers_path(@map),
         params: { marker: { lat: 999, lng: -74.0 } },
         as: :json

    assert_response :unprocessable_entity
  end

  test "update with invalid params via turbo_stream re-renders form" do
    patch map_marker_path(@map, @marker),
          params: { marker: { lat: 999 } },
          as: :turbo_stream

    assert_response :success
  end

  test "update with invalid params via json returns errors" do
    patch map_marker_path(@map, @marker),
          params: { marker: { lat: 999 } },
          as: :json

    assert_response :unprocessable_entity
  end

  test "destroy via json returns no_content" do
    marker = @map.markers.create!(lat: 40.0, lng: -74.0, title: "Temp")
    delete map_marker_path(@map, marker), as: :json
    assert_response :no_content
  end
end
