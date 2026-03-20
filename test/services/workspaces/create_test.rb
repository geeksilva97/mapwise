require "test_helper"

class Workspaces::CreateTest < ActiveSupport::TestCase
  test "creates workspace with admin membership for creator" do
    user = users(:one)

    workspace = Workspaces::Create.call(user, { name: "Team Alpha" })

    assert workspace.persisted?
    assert_not workspace.personal?
    assert_equal "Team Alpha", workspace.name
    assert_equal "admin", workspace.memberships.find_by(user: user).role
  end

  test "returns invalid workspace when name is blank" do
    workspace = Workspaces::Create.call(users(:one), { name: "" })
    assert_not workspace.persisted?
  end
end
