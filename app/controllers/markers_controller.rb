class MarkersController < ApplicationController
  before_action :set_map
  before_action :set_marker, only: %i[ edit update destroy ungroup ]

  def create
    @marker = Markers::Create.call(@map, marker_params)

    if @marker.persisted?
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
    if Markers::Update.call(@marker, marker_params)
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

  def ungroup
    Markers::Ungroup.call(@marker)
    respond_to do |format|
      format.json { render json: @marker }
    end
  end

  def destroy
    Markers::Destroy.call(@marker)
    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private

  def set_map
    @map = Maps::Find.call(Current.user, params[:map_id])
  end

  def set_marker
    @marker = Markers::Find.call(@map, params[:id])
  end

  def marker_params
    params.require(:marker).permit(:lat, :lng, :title, :description, :color, :icon, :position, :marker_group_id, :custom_info_html)
  end
end
