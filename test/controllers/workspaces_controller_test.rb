require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should get new" do
    get new_workspace_path
    assert_response :success
  end

  test "should create workspace" do
    assert_difference("Workspace.count") do
      post workspaces_path, params: { workspace: { name: "New Team" } }
    end

    workspace = Workspace.last
    assert_equal "New Team", workspace.name
    assert_not workspace.personal?
    assert_equal "admin", workspace.memberships.find_by(user: @user).role
    assert_redirected_to workspace_path(workspace)
  end

  test "should show workspace" do
    get workspace_path(workspaces(:one))
    assert_response :success
  end

  test "should get edit for admin" do
    get edit_workspace_path(workspaces(:one))
    assert_response :success
  end

  test "should update workspace as admin" do
    workspace = workspaces(:one)
    patch workspace_path(workspace), params: { workspace: { name: "Updated Name" } }
    assert_redirected_to workspace_path(workspace)
    assert_equal "Updated Name", workspace.reload.name
  end

  test "should not delete personal workspace" do
    delete workspace_path(workspaces(:one))
    assert_redirected_to workspace_path(workspaces(:one))
    assert Workspace.exists?(workspaces(:one).id)
  end

  test "should delete non-personal workspace as admin" do
    workspace = workspaces(:team)
    assert_difference("Workspace.count", -1) do
      delete workspace_path(workspace)
    end
    assert_redirected_to root_path
  end

  test "should switch workspace" do
    post switch_workspace_path(workspaces(:team))
    assert_redirected_to root_path
  end

  test "editor cannot edit workspace" do
    sign_in_as(users(:two))
    get edit_workspace_path(workspaces(:team))
    assert_redirected_to workspace_path(workspaces(:team))
  end

  test "editor cannot delete workspace" do
    sign_in_as(users(:two))
    assert_no_difference("Workspace.count") do
      delete workspace_path(workspaces(:team))
    end
    assert_redirected_to workspace_path(workspaces(:team))
  end

  test "cannot access workspace user is not a member of" do
    other_workspace = workspaces(:two)
    get workspace_path(other_workspace)
    assert_response :not_found
  end
end
