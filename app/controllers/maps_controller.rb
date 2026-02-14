class MapsController < ApplicationController
  before_action :set_map, only: %i[ show edit update destroy ]

  def new
    @map = Current.user.maps.build(center_lat: 39.8283, center_lng: -98.5795, zoom: 4)
  end

  def create
    @map = Current.user.maps.build(map_params)

    if @map.save
      redirect_to edit_map_path(@map)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @map.update(map_params)
      respond_to do |format|
        format.html { redirect_to edit_map_path(@map), notice: "Map updated." }
        format.json { head :ok }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @map.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @map.destroy
    redirect_to root_path, notice: "Map deleted.", status: :see_other
  end

  private

  def set_map
    @map = Current.user.maps.find(params[:id])
  end

  def map_params
    params.require(:map).permit(:title, :description, :center_lat, :center_lng,
                                :zoom, :map_type, :public, :style_json, :google_map_id)
  end
end
