require "test_helper"

class UserWorkspaceTest < ActiveSupport::TestCase
  test "personal_workspace returns the personal workspace" do
    user = users(:one)
    assert_equal workspaces(:one), user.personal_workspace
  end

  test "personal_workspace returns nil if no personal workspace" do
    user = User.create!(name: "No WS", email_address: "nows@example.com", password: "password123")
    assert_nil user.personal_workspace
  end

  test "has many workspaces through memberships" do
    user = users(:one)
    assert_includes user.workspaces, workspaces(:one)
    assert_includes user.workspaces, workspaces(:team)
  end
end
