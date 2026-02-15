class TrackingBroadcastJob < ApplicationJob
  queue_as :default

  def perform(tracking_point_id)
    point = TrackingPoint.find_by(id: tracking_point_id)
    return unless point

    vehicle = point.tracked_vehicle
    map = vehicle.map

    ActionCable.server.broadcast(
      "tracking_map_#{map.id}",
      {
        type: "tracking_point",
        vehicle_id: vehicle.id,
        vehicle_name: vehicle.name,
        vehicle_color: vehicle.color,
        point: {
          id: point.id,
          lat: point.lat,
          lng: point.lng,
          speed: point.speed,
          heading: point.heading,
          recorded_at: point.recorded_at.iso8601
        }
      }
    )
  end
end
