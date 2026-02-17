class Tracking::ClearPoints
  def self.call(vehicle)
    vehicle.tracking_points.delete_all
  end
end
