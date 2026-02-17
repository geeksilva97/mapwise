class WebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :check_email_verification_deadline
  skip_before_action :verify_authenticity_token

  def tracking
    vehicle = Tracking::FindVehicleByToken.call(params[:token])

    unless vehicle
      render json: { error: "Vehicle not found" }, status: :not_found
      return
    end

    unless vehicle.active?
      render json: { error: "Vehicle is inactive" }, status: :gone
      return
    end

    point = Tracking::CreateTrackingPoint.call(vehicle, params)

    if point.persisted?
      TrackingBroadcastJob.perform_later(point.id)
      DeviationCheckJob.perform_later(point.id) if vehicle.deviation_detection_enabled?
      render json: { point_id: point.id }, status: :ok
    else
      render json: { errors: point.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
