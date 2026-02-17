class Tracking::QueryPoints
  def self.call(vehicle, from:, to:)
    vehicle.tracking_points.in_range(from, to).chronological
  end
end
