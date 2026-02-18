require "test_helper"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(email_verified: false, email_verified_at: nil)
  end

  test "show with valid token verifies email and redirects to dashboard" do
    token = @user.generate_token_for(:email_verification)

    get email_verification_path(token)

    assert_redirected_to dashboard_path
    assert_equal "Email verified successfully!", flash[:notice]
    assert @user.reload.email_verified?
    assert_not_nil @user.email_verified_at
  end

  test "show with invalid token redirects to login with alert" do
    get email_verification_path("invalid-token")

    assert_redirected_to new_session_path
    assert_equal "Invalid or expired verification link.", flash[:alert]
  end

  test "show with expired token redirects to login with alert" do
    token = @user.generate_token_for(:email_verification)

    travel 4.days do
      get email_verification_path(token)

      assert_redirected_to new_session_path
      assert_equal "Invalid or expired verification link.", flash[:alert]
    end
  end

  test "show works without being logged in" do
    token = @user.generate_token_for(:email_verification)

    get email_verification_path(token)

    assert_redirected_to dashboard_path
    assert @user.reload.email_verified?
  end

  test "create resends verification email" do
    sign_in_as(@user)

    assert_enqueued_email_with UserMailer, :email_verification, args: [ @user ] do
      post resend_email_verification_path
    end

    assert_redirected_to dashboard_path
    assert_equal "Verification email sent. Please check your inbox.", flash[:notice]
  end

  test "create requires authentication" do
    post resend_email_verification_path
    assert_redirected_to new_session_path
  end

  test "expired user can still access email verification actions" do
    @user.update!(created_at: 10.days.ago)
    sign_in_as(@user)

    assert_enqueued_email_with UserMailer, :email_verification, args: [ @user ] do
      post resend_email_verification_path
    end

    assert_redirected_to dashboard_path
  end

  test "expired user is blocked from other pages" do
    @user.update!(created_at: 10.days.ago)
    sign_in_as(@user)

    get dashboard_path

    assert_response :forbidden
    assert_select "h1", "Email verification required"
  end

  test "unverified user within deadline can access pages normally" do
    @user.update!(created_at: 3.days.ago)
    sign_in_as(@user)

    get dashboard_path

    assert_response :success
  end

  test "verified user is not blocked" do
    @user.update!(email_verified: true, email_verified_at: 1.day.ago)
    sign_in_as(@user)

    get dashboard_path

    assert_response :success
  end
end
