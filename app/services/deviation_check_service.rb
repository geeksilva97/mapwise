class DeviationCheckService
  EARTH_RADIUS_METERS = 6_371_000.0

  # Check if a tracking point deviates from the vehicle's planned path.
  # Returns a DeviationAlert if deviation exceeds threshold, nil otherwise.
  def self.check(tracking_point)
    vehicle = tracking_point.tracked_vehicle
    return nil unless vehicle.deviation_detection_enabled?

    path_coords = parse_path_coordinates(vehicle.planned_path)
    return nil if path_coords.length < 2

    min_distance = minimum_distance_to_path(
      tracking_point.lat, tracking_point.lng, path_coords
    )

    return nil if min_distance <= vehicle.deviation_threshold_meters

    vehicle.deviation_alerts.create!(
      tracking_point: tracking_point,
      distance_meters: min_distance.round(1),
      message: "Vehicle deviated #{min_distance.round(1)}m from planned path"
    )
  end

  # Calculate the minimum distance from a point to any segment of the path
  def self.minimum_distance_to_path(lat, lng, path_coords)
    min = Float::INFINITY

    path_coords.each_cons(2) do |seg_start, seg_end|
      dist = cross_track_distance(lat, lng, seg_start, seg_end)
      min = dist if dist < min
    end

    min
  end

  # Cross-track distance: shortest distance from a point to a great-circle segment.
  # If the closest point on the great circle is outside the segment, uses the
  # endpoint distances instead.
  def self.cross_track_distance(lat, lng, seg_start, seg_end)
    # seg_start and seg_end are [lng, lat] (GeoJSON convention)
    lat1 = to_rad(seg_start[1])
    lng1 = to_rad(seg_start[0])
    lat2 = to_rad(seg_end[1])
    lng2 = to_rad(seg_end[0])
    lat_p = to_rad(lat)
    lng_p = to_rad(lng)

    d13 = haversine_distance_rad(lat1, lng1, lat_p, lng_p)
    bearing13 = initial_bearing_rad(lat1, lng1, lat_p, lng_p)
    bearing12 = initial_bearing_rad(lat1, lng1, lat2, lng2)

    # Cross-track distance
    dxt = Math.asin(Math.sin(d13) * Math.sin(bearing13 - bearing12)).abs

    # Along-track distance from start
    dat = Math.acos(Math.cos(d13) / [ Math.cos(dxt), 1e-15 ].max)

    # Distance of the full segment
    d12 = haversine_distance_rad(lat1, lng1, lat2, lng2)

    if dat > d12
      # Past the end of the segment — use distance to endpoint
      haversine_meters(lat, lng, seg_end[1], seg_end[0])
    elsif dat < 0
      # Before the start — use distance to start point
      haversine_meters(lat, lng, seg_start[1], seg_start[0])
    else
      dxt * EARTH_RADIUS_METERS
    end
  end

  # Haversine distance in meters between two lat/lng points
  def self.haversine_meters(lat1, lng1, lat2, lng2)
    haversine_distance_rad(to_rad(lat1), to_rad(lng1), to_rad(lat2), to_rad(lng2)) * EARTH_RADIUS_METERS
  end

  # Haversine distance in radians (inputs already in radians)
  def self.haversine_distance_rad(lat1, lng1, lat2, lng2)
    dlat = lat2 - lat1
    dlng = lng2 - lng1
    a = Math.sin(dlat / 2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dlng / 2)**2
    2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  end

  # Initial bearing in radians
  def self.initial_bearing_rad(lat1, lng1, lat2, lng2)
    dlng = lng2 - lng1
    y = Math.sin(dlng) * Math.cos(lat2)
    x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dlng)
    Math.atan2(y, x)
  end

  def self.to_rad(degrees)
    degrees * Math::PI / 180.0
  end

  def self.parse_path_coordinates(geojson_string)
    data = JSON.parse(geojson_string)
    coords = if data["type"] == "Feature"
      data.dig("geometry", "coordinates")
    elsif data["type"] == "LineString"
      data["coordinates"]
    else
      []
    end
    coords || []
  rescue JSON::ParserError
    []
  end

  private_class_method :haversine_distance_rad, :initial_bearing_rad, :to_rad, :parse_path_coordinates
end
