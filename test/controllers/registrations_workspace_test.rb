require "test_helper"

class RegistrationsWorkspaceTest < ActionDispatch::IntegrationTest
  test "registration creates personal workspace" do
    assert_difference([ "User.count", "Workspace.count", "Membership.count" ]) do
      post registration_path, params: {
        user: {
          name: "New Person",
          email_address: "newperson@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    user = User.find_by(email_address: "newperson@example.com")
    assert user.personal_workspace.present?
    assert user.personal_workspace.personal?
    assert_equal "admin", user.personal_workspace.memberships.find_by(user: user).role
  end
end
