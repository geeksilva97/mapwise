require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new renders sign-up form" do
    get new_registration_path
    assert_response :success
    assert_select "h1", "Sign up"
  end

  test "create with valid params creates user and starts session" do
    assert_difference("User.count") do
      post registration_path, params: {
        user: {
          name: "New User",
          email_address: "new@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_path
    assert cookies[:session_id].present?

    user = User.find_by(email_address: "new@example.com")
    assert_equal "New User", user.name
  end

  test "create with invalid params re-renders form with errors" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          name: "",
          email_address: "bad",
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with mismatched password confirmation" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          name: "Test",
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "different456"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with duplicate email" do
    existing = users(:one)

    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          name: "Duplicate",
          email_address: existing.email_address,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
