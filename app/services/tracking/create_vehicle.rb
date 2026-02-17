class Tracking::CreateVehicle
  def self.call(map, params)
    vehicle = map.tracked_vehicles.build(params)
    vehicle.save
    vehicle
  end
end
