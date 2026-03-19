require "test_helper"

class MarkerGroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @map = maps(:one)
    @group = marker_groups(:restaurants)
    sign_in_as(@user)
  end

  test "create with valid params via turbo_stream" do
    assert_difference("MarkerGroup.count") do
      post map_marker_groups_path(@map),
           params: { marker_group: { name: "Parks", color: "#22C55E" } },
           as: :turbo_stream
    end

    assert_response :success
    group = MarkerGroup.last
    assert_equal "Parks", group.name
    assert_equal "#22C55E", group.color
    assert_equal @map, group.map
  end

  test "create with valid params via json" do
    assert_difference("MarkerGroup.count") do
      post map_marker_groups_path(@map),
           params: { marker_group: { name: "Cafes" } },
           as: :json
    end

    assert_response :success
  end

  test "create with missing name returns error" do
    assert_no_difference("MarkerGroup.count") do
      post map_marker_groups_path(@map),
           params: { marker_group: { color: "#FF0000" } },
           as: :json
    end

    assert_response :unprocessable_entity
  end

  test "update changes group attributes" do
    patch map_marker_group_path(@map, @group),
          params: { marker_group: { name: "Diners", color: "#EAB308" } },
          as: :json

    assert_response :success
    @group.reload
    assert_equal "Diners", @group.name
    assert_equal "#EAB308", @group.color
  end

  test "destroy removes group" do
    assert_difference("MarkerGroup.count", -1) do
      delete map_marker_group_path(@map, @group), as: :turbo_stream
    end

    assert_response :success
  end

  test "destroy via json" do
    assert_difference("MarkerGroup.count", -1) do
      delete map_marker_group_path(@map, @group), as: :json
    end

    assert_response :no_content
  end

  test "toggle_visibility toggles group visibility" do
    assert @group.visible?

    patch toggle_visibility_map_marker_group_path(@map, @group), as: :json
    assert_response :success
    @group.reload
    assert_not @group.visible?

    patch toggle_visibility_map_marker_group_path(@map, @group), as: :json
    assert_response :success
    @group.reload
    assert @group.visible?
  end

  test "groups are scoped to parent map" do
    other_group = marker_groups(:on_other_map)
    patch map_marker_group_path(@map, other_group),
          params: { marker_group: { name: "Hacked" } },
          as: :json

    assert_response :not_found
  end

  test "user cannot CRUD groups on other user's maps" do
    other_map = maps(:two)
    post map_marker_groups_path(other_map),
         params: { marker_group: { name: "Hack" } },
         as: :json

    assert_response :not_found
  end

  test "assign_markers assigns markers to group" do
    marker_one = markers(:one)
    marker_two = markers(:two_on_one)

    patch assign_markers_map_marker_group_path(@map, @group),
          params: { marker_ids: [ marker_one.id, marker_two.id ] },
          as: :json

    assert_response :success
    marker_one.reload
    marker_two.reload
    assert_equal @group.id, marker_one.marker_group_id
    assert_equal @group.id, marker_two.marker_group_id
    assert_equal @group.color, marker_one.color
    assert_equal @group.color, marker_two.color

    json = JSON.parse(response.body)
    assert_equal @group.id, json["id"]
    assert_equal 2, json["assigned_count"]
  end

  test "assign_markers ignores markers from other maps" do
    other_marker = markers(:on_other_map)

    patch assign_markers_map_marker_group_path(@map, @group),
          params: { marker_ids: [ other_marker.id ] },
          as: :json

    assert_response :success
    other_marker.reload
    assert_nil other_marker.marker_group_id

    json = JSON.parse(response.body)
    assert_equal 0, json["assigned_count"]
  end

  test "assign_markers with empty marker_ids" do
    patch assign_markers_map_marker_group_path(@map, @group),
          params: { marker_ids: [] },
          as: :json

    assert_response :success
  end

  test "assign_markers requires authentication" do
    sign_out
    patch assign_markers_map_marker_group_path(@map, @group),
          params: { marker_ids: [ markers(:one).id ] },
          as: :json

    assert_redirected_to new_session_path
  end

  test "create with missing name via turbo_stream re-renders form" do
    assert_no_difference("MarkerGroup.count") do
      post map_marker_groups_path(@map),
           params: { marker_group: { color: "#FF0000" } },
           as: :turbo_stream
    end

    assert_response :success
  end

  test "update with invalid params via turbo_stream re-renders form" do
    patch map_marker_group_path(@map, @group),
          params: { marker_group: { name: "" } },
          as: :turbo_stream

    assert_response :success
  end

  test "update with invalid params via json returns errors" do
    patch map_marker_group_path(@map, @group),
          params: { marker_group: { name: "" } },
          as: :json

    assert_response :unprocessable_entity
  end

  test "update via turbo_stream" do
    patch map_marker_group_path(@map, @group),
          params: { marker_group: { name: "Updated TS" } },
          as: :turbo_stream

    assert_response :success
    assert_equal "Updated TS", @group.reload.name
  end

  test "toggle_visibility via turbo_stream" do
    assert @group.visible?
    patch toggle_visibility_map_marker_group_path(@map, @group), as: :turbo_stream
    assert_response :success
    assert_not @group.reload.visible?
  end

  test "create requires authentication" do
    sign_out
    post map_marker_groups_path(@map),
         params: { marker_group: { name: "Test" } },
         as: :json

    assert_redirected_to new_session_path
  end

  test "create ignores unpermitted params" do
    assert_difference("MarkerGroup.count") do
      post map_marker_groups_path(@map),
           params: { marker_group: { name: "Safe", color: "#FF0000", map_id: 999, position: 0 } },
           as: :json
    end

    group = MarkerGroup.last
    assert_equal @map.id, group.map_id
  end

  test "assign_markers ignores unpermitted params" do
    marker = markers(:one)
    patch assign_markers_map_marker_group_path(@map, @group),
          params: { marker_ids: [ marker.id ], group_id: 999, map_id: 999 },
          as: :json

    assert_response :success
    assert_equal @group.id, marker.reload.marker_group_id
  end
end
