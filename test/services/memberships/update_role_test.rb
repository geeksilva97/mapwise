require "test_helper"

class Memberships::UpdateRoleTest < ActiveSupport::TestCase
  test "updates role" do
    membership = memberships(:two_team_editor)
    result = Memberships::UpdateRole.call(membership, "admin")
    assert result[:membership]
    assert_equal "admin", membership.reload.role
  end

  test "prevents demoting last admin" do
    memberships(:two_team_editor).destroy

    membership = memberships(:one_team_admin)
    result = Memberships::UpdateRole.call(membership, "editor")
    assert_equal "Cannot demote the last admin", result[:error]
    assert_equal "admin", membership.reload.role
  end

  test "allows demoting admin when another admin exists" do
    memberships(:two_team_editor).update!(role: "admin")

    membership = memberships(:one_team_admin)
    result = Memberships::UpdateRole.call(membership, "editor")
    assert result[:membership]
    assert_equal "editor", membership.reload.role
  end

  test "rejects invalid role" do
    membership = memberships(:two_team_editor)
    result = Memberships::UpdateRole.call(membership, "superadmin")
    assert result[:error]
    assert_equal "editor", membership.reload.role
  end
end
