class TrackedVehiclesController < ApplicationController
  before_action :set_map
  before_action :set_vehicle, only: %i[ edit update destroy toggle_active clear_points save_planned_path points ]

  def create
    @vehicle = Tracking::CreateVehicle.call(@map, vehicle_params)

    if @vehicle.persisted?
      respond_to do |format|
        format.turbo_stream
        format.json { render json: vehicle_json(@vehicle), status: :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("vehicle_form", partial: "tracked_vehicles/form", locals: { map: @map, vehicle: @vehicle }) }
        format.json { render json: @vehicle.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    respond_to do |format|
      format.turbo_stream
      format.json { render json: vehicle_json(@vehicle) }
    end
  end

  def update
    if Tracking::UpdateVehicle.call(@vehicle, vehicle_params)
      respond_to do |format|
        format.turbo_stream
        format.json { render json: vehicle_json(@vehicle) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("vehicle_form", partial: "tracked_vehicles/form", locals: { map: @map, vehicle: @vehicle }) }
        format.json { render json: @vehicle.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Tracking::DestroyVehicle.call(@vehicle)
    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def toggle_active
    Tracking::ToggleActive.call(@vehicle)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("vehicle_#{@vehicle.id}", partial: "tracked_vehicles/vehicle_item", locals: { vehicle: @vehicle, map: @map }) }
      format.json { render json: vehicle_json(@vehicle) }
    end
  end

  def clear_points
    Tracking::ClearPoints.call(@vehicle)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("vehicle_#{@vehicle.id}", partial: "tracked_vehicles/vehicle_item", locals: { vehicle: @vehicle, map: @map }) }
      format.json { head :no_content }
    end
  end

  def save_planned_path
    if Tracking::SavePlannedPath.call(@vehicle, planned_path_params[:planned_path])
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("vehicle_#{@vehicle.id}", partial: "tracked_vehicles/vehicle_item", locals: { vehicle: @vehicle, map: @map }) }
        format.json { render json: vehicle_json(@vehicle) }
      end
    else
      respond_to do |format|
        format.json { render json: @vehicle.errors, status: :unprocessable_entity }
      end
    end
  end

  def points
    from = params[:from] ? Time.zone.parse(params[:from]) : 24.hours.ago
    to = params[:to] ? Time.zone.parse(params[:to]) : Time.current
    limit = params[:limit] ? params[:limit].to_i.clamp(1, 10_000) : nil

    points = Tracking::QueryPoints.call(@vehicle, from: from, to: to, limit: limit)
    render json: points.select(:id, :lat, :lng, :speed, :heading, :recorded_at)
  end

  private

  def set_map
    @map = Maps::Find.call(Current.workspace, params[:map_id])
  end

  def set_vehicle
    @vehicle = Tracking::FindVehicle.call(@map, params[:id])
  end

  def vehicle_params
    params.require(:tracked_vehicle).permit(:name, :color, :icon, :deviation_threshold_meters, :planned_path)
  end

  def planned_path_params
    params.permit(:planned_path)
  end

  def vehicle_json(vehicle)
    vehicle.as_json(only: %i[id name webhook_token color icon active planned_path deviation_threshold_meters position]).merge(
      webhook_url: webhook_tracking_url(vehicle.webhook_token),
      last_point: vehicle.last_tracking_point&.as_json(only: %i[lat lng speed heading recorded_at])
    )
  end
end
