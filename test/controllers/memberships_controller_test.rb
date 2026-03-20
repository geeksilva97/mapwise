require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @workspace = workspaces(:team)
    sign_in_as(@admin)
  end

  test "admin can invite a member" do
    new_user = User.create!(name: "New User", email_address: "newuser@example.com", password: "password123")

    assert_difference("Membership.count") do
      post workspace_memberships_path(@workspace), params: { email: "newuser@example.com", role: "editor" }
    end

    assert_redirected_to workspace_path(@workspace)
    membership = @workspace.memberships.find_by(user: new_user)
    assert_equal "editor", membership.role
  end

  test "invite fails for nonexistent user" do
    assert_no_difference("Membership.count") do
      post workspace_memberships_path(@workspace), params: { email: "nobody@example.com", role: "editor" }
    end

    assert_redirected_to workspace_path(@workspace)
    assert_match "User not found", flash[:alert]
  end

  test "admin can update member role" do
    membership = memberships(:two_team_editor)
    patch workspace_membership_path(@workspace, membership), params: { role: "admin" }
    assert_redirected_to workspace_path(@workspace)
    assert_equal "admin", membership.reload.role
  end

  test "admin can remove a member" do
    membership = memberships(:two_team_editor)
    assert_difference("Membership.count", -1) do
      delete workspace_membership_path(@workspace, membership)
    end
    assert_redirected_to workspace_path(@workspace)
  end

  test "cannot remove last admin" do
    # Remove user two first so only user one (admin) remains
    memberships(:two_team_editor).destroy

    membership = memberships(:one_team_admin)
    assert_no_difference("Membership.count") do
      delete workspace_membership_path(@workspace, membership)
    end
    assert_redirected_to workspace_path(@workspace)
    assert_match "Cannot remove the last admin", flash[:alert]
  end

  test "editor cannot invite members" do
    sign_in_as(users(:two))
    assert_no_difference("Membership.count") do
      post workspace_memberships_path(@workspace), params: { email: "test@example.com", role: "editor" }
    end
    assert_redirected_to workspace_path(@workspace)
  end

  test "editor cannot remove members" do
    sign_in_as(users(:two))
    membership = memberships(:one_team_admin)
    assert_no_difference("Membership.count") do
      delete workspace_membership_path(@workspace, membership)
    end
    assert_redirected_to workspace_path(@workspace)
  end
end
