class Tracking::CreateTrackingPoint
  def self.call(vehicle, params)
    point = vehicle.tracking_points.build(
      lat: params[:lat],
      lng: params[:lng],
      speed: params[:speed],
      heading: params[:heading],
      recorded_at: params[:recorded_at] || Time.current
    )
    point.save
    point
  end
end
