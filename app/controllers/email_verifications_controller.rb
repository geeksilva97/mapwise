class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access only: :show
  skip_before_action :check_email_verification_deadline

  def show
    user = EmailVerifications::Verify.call(params[:token])

    if user
      redirect_to dashboard_path, notice: "Email verified successfully!"
    else
      redirect_to new_session_path, alert: "Invalid or expired verification link."
    end
  end

  def create
    EmailVerifications::Send.call(Current.user)
    redirect_back fallback_location: dashboard_path, notice: "Verification email sent. Please check your inbox."
  end
end
