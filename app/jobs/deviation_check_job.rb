class DeviationCheckJob < ApplicationJob
  queue_as :default

  def perform(tracking_point_id)
    point = TrackingPoint.find_by(id: tracking_point_id)
    return unless point

    vehicle = point.tracked_vehicle
    return unless vehicle.deviation_detection_enabled?

    alert = DeviationCheckService.check(point)

    if alert
      map = vehicle.map
      ActionCable.server.broadcast(
        "tracking_map_#{map.id}",
        {
          type: "deviation_alert",
          vehicle_id: vehicle.id,
          vehicle_name: vehicle.name,
          alert: {
            id: alert.id,
            distance_meters: alert.distance_meters,
            message: alert.message,
            created_at: alert.created_at.iso8601
          }
        }
      )
    end
  end
end
