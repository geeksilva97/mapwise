class SettingsController < ApplicationController
  def show
    @user = Current.user
    @api_key = Current.workspace.api_keys.first || ApiKey.new
  end

  def update
    @user = Current.user

    if @user.update(user_params)
      redirect_to settings_path, notice: "Settings saved."
    else
      @api_key = Current.workspace.api_keys.first || ApiKey.new
      render :show, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email_address)
  end
end
