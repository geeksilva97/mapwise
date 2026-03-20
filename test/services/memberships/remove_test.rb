require "test_helper"

class Memberships::RemoveTest < ActiveSupport::TestCase
  test "removes a member" do
    membership = memberships(:two_team_editor)
    result = Memberships::Remove.call(membership)
    assert result[:membership].destroyed?
  end

  test "prevents removing last admin" do
    # Remove all non-admin members first
    memberships(:two_team_editor).destroy

    membership = memberships(:one_team_admin)
    result = Memberships::Remove.call(membership)
    assert_equal "Cannot remove the last admin", result[:error]
    assert_not membership.destroyed?
  end
end
