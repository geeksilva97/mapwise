class MarkerGroupsController < ApplicationController
  before_action :set_map
  before_action :set_marker_group, only: %i[ update destroy toggle_visibility assign_markers ]

  def create
    @marker_group = @map.marker_groups.build(marker_group_params)

    if @marker_group.save
      respond_to do |format|
        format.turbo_stream
        format.json { render json: @marker_group }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("group_form", partial: "marker_groups/form", locals: { map: @map, marker_group: @marker_group }) }
        format.json { render json: @marker_group.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @marker_group.update(marker_group_params)
      respond_to do |format|
        format.turbo_stream
        format.json { render json: @marker_group }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("group_form", partial: "marker_groups/form", locals: { map: @map, marker_group: @marker_group }) }
        format.json { render json: @marker_group.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @marker_group.destroy
    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def assign_markers
    marker_ids = params[:marker_ids] || []
    markers = @map.markers.where(id: marker_ids)
    markers.update_all(marker_group_id: @marker_group.id, color: @marker_group.color)

    respond_to do |format|
      format.json { render json: { id: @marker_group.id, name: @marker_group.name, assigned_count: markers.count } }
    end
  end

  def toggle_visibility
    @marker_group.update!(visible: !@marker_group.visible)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("group_#{@marker_group.id}", partial: "marker_groups/group_section", locals: { map: @map, group: @marker_group }) }
      format.json { render json: @marker_group }
    end
  end

  private

  def set_map
    @map = Current.user.maps.find(params[:map_id])
  end

  def set_marker_group
    @marker_group = @map.marker_groups.find(params[:id])
  end

  def marker_group_params
    params.require(:marker_group).permit(:name, :color, :icon, :visible)
  end
end
