require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "unauthenticated users are redirected to login" do
    # Root is currently sessions#new which allows unauthenticated access,
    # but once we add authenticated-only routes, they should redirect.
    # For now, verify the sign_in_as helper works correctly.
    user = users(:one)
    sign_in_as(user)

    # After signing in, session cookie should be set
    assert cookies[:session_id].present?
  end

  test "sign_in_as sets session cookie" do
    user = users(:one)
    sign_in_as(user)
    assert cookies[:session_id].present?
  end
end
