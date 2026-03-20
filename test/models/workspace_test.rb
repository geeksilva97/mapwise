require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "validates presence of name" do
    workspace = Workspace.new
    assert_not workspace.valid?
    assert_includes workspace.errors[:name], "can't be blank"
  end

  test "valid with name" do
    workspace = Workspace.new(name: "Test Workspace")
    assert workspace.valid?
  end

  test "has many memberships" do
    workspace = workspaces(:one)
    assert_respond_to workspace, :memberships
  end

  test "has many users through memberships" do
    workspace = workspaces(:team)
    assert_includes workspace.users, users(:one)
    assert_includes workspace.users, users(:two)
  end

  test "has many maps" do
    workspace = workspaces(:one)
    assert workspace.maps.count >= 1
  end

  test "has many api_keys" do
    workspace = workspaces(:one)
    assert workspace.api_keys.count >= 1
  end

  test "personal defaults to false" do
    workspace = Workspace.new(name: "Team")
    assert_equal false, workspace.personal
  end
end
