class Tracking::SavePlannedPath
  def self.call(vehicle, path)
    vehicle.update(planned_path: path)
  end
end
