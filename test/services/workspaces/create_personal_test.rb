require "test_helper"

class Workspaces::CreatePersonalTest < ActiveSupport::TestCase
  test "creates a personal workspace with admin membership" do
    user = User.create!(name: "Test User", email_address: "test_ws@example.com", password: "password123")

    workspace = Workspaces::CreatePersonal.call(user)

    assert workspace.persisted?
    assert workspace.personal?
    assert_equal "Test User's Workspace", workspace.name
    assert_equal "admin", workspace.memberships.find_by(user: user).role
  end
end
