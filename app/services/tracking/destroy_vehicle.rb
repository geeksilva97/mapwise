class Tracking::DestroyVehicle
  def self.call(vehicle)
    vehicle.destroy
  end
end
