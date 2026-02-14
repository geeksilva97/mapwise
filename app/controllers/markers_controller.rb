class MarkersController < ApplicationController
  before_action :set_map
  before_action :set_marker, only: %i[ edit update destroy ]

  def create
    @marker = @map.markers.build(marker_params)

    if @marker.save
      respond_to do |format|
        format.turbo_stream
        format.json { render json: @marker }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("marker_form", partial: "markers/form", locals: { map: @map, marker: @marker }) }
        format.json { render json: @marker.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @marker.update(marker_params)
      respond_to do |format|
        format.turbo_stream
        format.json { render json: @marker }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("marker_form", partial: "markers/form", locals: { map: @map, marker: @marker }) }
        format.json { render json: @marker.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @marker.destroy
    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private

  def set_map
    @map = Current.user.maps.find(params[:map_id])
  end

  def set_marker
    @marker = @map.markers.find(params[:id])
  end

  def marker_params
    params.require(:marker).permit(:lat, :lng, :title, :description, :color, :icon, :position)
  end
end
