class MapStylesController < ApplicationController
  def create
    @map_style = Current.user.map_styles.build(map_style_params)

    if @map_style.save
      redirect_back fallback_location: root_path, notice: "Style created."
    else
      redirect_back fallback_location: root_path, alert: "Could not create style."
    end
  end

  def destroy
    @map_style = MapStyle.for_user(Current.user).find(params[:id])

    if @map_style.system_default?
      redirect_back fallback_location: root_path, alert: "Cannot delete system presets."
    else
      @map_style.destroy
      redirect_back fallback_location: root_path, notice: "Style deleted."
    end
  end

  private

  def map_style_params
    params.require(:map_style).permit(:name, :style_json)
  end
end
