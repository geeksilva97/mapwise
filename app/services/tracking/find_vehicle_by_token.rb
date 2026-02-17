class Tracking::FindVehicleByToken
  def self.call(token)
    ::TrackedVehicle.find_by(webhook_token: token)
  end
end
