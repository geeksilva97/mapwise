require "test_helper"

class Memberships::InviteTest < ActiveSupport::TestCase
  test "invites existing user to workspace" do
    workspace = workspaces(:one)
    user = users(:two)

    result = Memberships::Invite.call(workspace, user.email_address, role: "editor")

    assert result[:membership].persisted?
    assert_equal "editor", result[:membership].role
  end

  test "returns error for nonexistent user" do
    result = Memberships::Invite.call(workspaces(:one), "nobody@example.com")
    assert_equal "User not found", result[:error]
  end

  test "returns error for duplicate membership" do
    workspace = workspaces(:team)
    user = users(:one) # already a member

    result = Memberships::Invite.call(workspace, user.email_address)
    assert result[:error].present?
  end
end
