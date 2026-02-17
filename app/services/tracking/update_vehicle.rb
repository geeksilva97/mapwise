class Tracking::UpdateVehicle
  def self.call(vehicle, params)
    vehicle.update(params)
  end
end
