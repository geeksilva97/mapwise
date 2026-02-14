class MapStylesController < ApplicationController
  def index
    @styles = MapStyle.for_user(Current.user).order(:system_default => :desc, :name => :asc)
  end

  def create
    @map_style = Current.user.map_styles.build(map_style_params)

    if @map_style.save
      redirect_to map_styles_path, notice: "Style created."
    else
      @styles = MapStyle.for_user(Current.user)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @map_style = MapStyle.for_user(Current.user).find(params[:id])

    if @map_style.system_default?
      redirect_to map_styles_path, alert: "Cannot delete system presets."
    else
      @map_style.destroy
      redirect_to map_styles_path, notice: "Style deleted."
    end
  end

  private

  def map_style_params
    params.require(:map_style).permit(:name, :style_json)
  end
end
