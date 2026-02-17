class Tracking::FindVehicle
  def self.call(map, id)
    map.tracked_vehicles.find(id)
  end
end
