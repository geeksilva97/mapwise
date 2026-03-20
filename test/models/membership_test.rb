require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "validates role inclusion" do
    membership = Membership.new(user: users(:one), workspace: workspaces(:two), role: "invalid")
    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "validates uniqueness of user per workspace" do
    existing = memberships(:one_personal)
    duplicate = Membership.new(user: existing.user, workspace: existing.workspace, role: "editor")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "admin?" do
    assert memberships(:one_personal).admin?
    assert_not memberships(:two_team_editor).admin?
  end

  test "editor?" do
    assert memberships(:two_team_editor).editor?
    assert_not memberships(:one_personal).editor?
  end

  test "default role is editor" do
    membership = Membership.new
    assert_equal "editor", membership.role
  end
end
