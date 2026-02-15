class WebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :verify_authenticity_token

  def tracking
    vehicle = TrackedVehicle.find_by(webhook_token: params[:token])

    unless vehicle
      render json: { error: "Vehicle not found" }, status: :not_found
      return
    end

    unless vehicle.active?
      render json: { error: "Vehicle is inactive" }, status: :gone
      return
    end

    point = vehicle.tracking_points.build(
      lat: params[:lat],
      lng: params[:lng],
      speed: params[:speed],
      heading: params[:heading],
      recorded_at: params[:recorded_at] || Time.current
    )

    if point.save
      TrackingBroadcastJob.perform_later(point.id)
      DeviationCheckJob.perform_later(point.id) if vehicle.deviation_detection_enabled?
      render json: { point_id: point.id }, status: :ok
    else
      render json: { errors: point.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
