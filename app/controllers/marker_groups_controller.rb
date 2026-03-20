class MarkerGroupsController < ApplicationController
  before_action :set_map
  before_action :set_marker_group, only: %i[ update destroy toggle_visibility assign_markers ]

  def create
    @marker_group = MarkerGroups::Create.call(@map, marker_group_params)

    if @marker_group.persisted?
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
    if MarkerGroups::Update.call(@marker_group, marker_group_params)
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
    MarkerGroups::Destroy.call(@marker_group)
    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def assign_markers
    marker_ids = params.permit(marker_ids: []).fetch(:marker_ids, [])
    markers = MarkerGroups::AssignMarkers.call(@map, @marker_group, marker_ids)

    respond_to do |format|
      format.json { render json: { id: @marker_group.id, name: @marker_group.name, assigned_count: markers.count } }
    end
  end

  def toggle_visibility
    MarkerGroups::ToggleVisibility.call(@marker_group)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("group_#{@marker_group.id}", partial: "marker_groups/group_section", locals: { map: @map, group: @marker_group }) }
      format.json { render json: @marker_group }
    end
  end

  private

  def set_map
    @map = Maps::Find.call(Current.workspace, params[:map_id])
  end

  def set_marker_group
    @marker_group = MarkerGroups::Find.call(@map, params[:id])
  end

  def marker_group_params
    params.require(:marker_group).permit(:name, :color, :icon, :visible)
  end
end
