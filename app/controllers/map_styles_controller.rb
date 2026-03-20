class MapStylesController < ApplicationController
  def create
    @map_style = MapStyles::Create.call(Current.workspace, Current.user, map_style_params)

    if @map_style.persisted?
      redirect_back fallback_location: root_path, notice: "Style created."
    else
      redirect_back fallback_location: root_path, alert: "Could not create style."
    end
  end

  def destroy
    result = MapStyles::Destroy.call(Current.workspace, params[:id])

    if result.is_a?(Hash) && result[:error]
      redirect_back fallback_location: root_path, alert: result[:error]
    else
      redirect_back fallback_location: root_path, notice: "Style deleted."
    end
  end

  private

  def map_style_params
    params.require(:map_style).permit(:name, :style_json)
  end
end
