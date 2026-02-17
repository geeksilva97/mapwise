class Tracking::ToggleActive
  def self.call(vehicle)
    vehicle.update!(active: !vehicle.active?)
  end
end
