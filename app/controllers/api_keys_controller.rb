class ApiKeysController < ApplicationController
  before_action :set_api_key, only: %i[ update destroy ]

  def create
    @api_key = ApiKeys::Create.call(Current.user, api_key_params)

    if @api_key.persisted?
      redirect_to settings_path(tab: "google maps"), notice: "Google Maps API key saved."
    else
      @user = Current.user
      render "settings/show", status: :unprocessable_entity
    end
  end

  def update
    if ApiKeys::Update.call(@api_key, api_key_params)
      redirect_to settings_path(tab: "google maps"), notice: "Google Maps API key updated."
    else
      @user = Current.user
      render "settings/show", status: :unprocessable_entity
    end
  end

  def destroy
    ApiKeys::Destroy.call(@api_key)
    redirect_to settings_path(tab: "google maps"), notice: "Google Maps API key removed."
  end

  private

  def set_api_key
    @api_key = ApiKeys::Find.call(Current.user, params[:id])
  end

  def api_key_params
    params.require(:api_key).permit(:google_maps_key)
  end
end
