class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  skip_before_action :check_email_verification_deadline
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      Workspaces::CreatePersonal.call(@user)
      start_new_session_for(@user)
      EmailVerifications::Send.call(@user)
      redirect_to root_path, notice: "Welcome to #{Branding.app_name}! Please check your email to verify your account."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
  end
end
