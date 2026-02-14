class ApiKeysController < ApplicationController
  before_action :set_api_key, only: %i[ update destroy ]

  def index
    @api_keys = Current.user.api_keys
    @api_key = ApiKey.new
  end

  def create
    @api_key = Current.user.api_keys.build(api_key_params)

    if @api_key.save
      redirect_to api_keys_path, notice: "API key saved."
    else
      @api_keys = Current.user.api_keys.reload
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @api_key.update(api_key_params)
      redirect_to api_keys_path, notice: "API key updated."
    else
      @api_keys = Current.user.api_keys
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @api_key.destroy
    redirect_to api_keys_path, notice: "API key removed."
  end

  private

  def set_api_key
    @api_key = Current.user.api_keys.find(params[:id])
  end

  def api_key_params
    params.require(:api_key).permit(:google_maps_key, :label)
  end
end
