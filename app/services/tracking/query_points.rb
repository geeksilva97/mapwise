class Tracking::QueryPoints
  def self.call(vehicle, from:, to:, limit: nil)
    scope = vehicle.tracking_points.in_range(from, to).chronological
    limit ? scope.limit(limit) : scope
  end
end
