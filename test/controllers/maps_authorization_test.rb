require "test_helper"

class MapsAuthorizationTest < ActionDispatch::IntegrationTest
  test "editor cannot delete maps" do
    sign_in_as(users(:two))

    # Switch to team workspace where user two is editor
    post switch_workspace_path(workspaces(:team))

    # Create a map in team workspace
    post maps_path, params: { map: { title: "Team Map" } }
    map = Map.find_by(title: "Team Map")

    # Try to delete — should be forbidden
    assert_no_difference("Map.count") do
      delete map_path(map)
    end

    assert_redirected_to root_path
  end

  test "admin can delete maps" do
    sign_in_as(users(:one))

    map = maps(:one)
    assert_difference("Map.count", -1) do
      delete map_path(map)
    end
  end
end
