require "test_helper"

class DeviationCheckServiceTest < ActiveSupport::TestCase
  setup do
    @vehicle = tracked_vehicles(:courier_bike)
    # courier_bike has planned_path: LineString from [-74.006, 40.7128] to [-73.99, 40.72] to [-73.98, 40.73]
    # and deviation_threshold_meters: 100.0
  end

  test "haversine_meters calculates distance between two points" do
    # NYC to very nearby point — known distance roughly
    dist = DeviationCheckService.haversine_meters(40.7128, -74.0060, 40.7138, -74.0050)
    assert_in_delta 130, dist, 20  # ~130m apart
  end

  test "haversine_meters gives zero for same point" do
    dist = DeviationCheckService.haversine_meters(40.7128, -74.0060, 40.7128, -74.0060)
    assert_in_delta 0, dist, 0.01
  end

  test "minimum_distance_to_path for point on path" do
    # Point right on the path start
    path = [ [ -74.006, 40.7128 ], [ -73.99, 40.72 ] ]
    dist = DeviationCheckService.minimum_distance_to_path(40.7128, -74.006, path)
    assert_in_delta 0, dist, 1.0  # within 1m
  end

  test "minimum_distance_to_path for distant point" do
    path = [ [ -74.006, 40.7128 ], [ -73.99, 40.72 ] ]
    # Point far from path
    dist = DeviationCheckService.minimum_distance_to_path(40.80, -73.90, path)
    assert dist > 1000  # should be > 1km away
  end

  test "check returns nil when point is on path" do
    # Create a point right on the path
    point = @vehicle.tracking_points.create!(
      lat: 40.7128, lng: -74.006, recorded_at: Time.current
    )
    result = DeviationCheckService.check(point)
    assert_nil result
  end

  test "check creates alert when point deviates beyond threshold" do
    # Point far from the path — should exceed 100m threshold
    point = @vehicle.tracking_points.create!(
      lat: 40.80, lng: -73.90, recorded_at: Time.current
    )
    assert_difference "DeviationAlert.count", 1 do
      alert = DeviationCheckService.check(point)
      assert_not_nil alert
      assert_kind_of DeviationAlert, alert
      assert alert.distance_meters > 100
      assert_equal point, alert.tracking_point
      assert_equal @vehicle, alert.tracked_vehicle
      assert_includes alert.message, "deviated"
    end
  end

  test "check returns nil when deviation detection disabled" do
    vehicle = tracked_vehicles(:delivery_truck)  # no planned_path
    point = vehicle.tracking_points.create!(
      lat: 50.0, lng: 0.0, recorded_at: Time.current
    )
    result = DeviationCheckService.check(point)
    assert_nil result
  end

  test "check returns nil when path has fewer than 2 coords" do
    @vehicle.update!(planned_path: '{"type":"Feature","geometry":{"type":"LineString","coordinates":[[-74,40.7]]}}')
    point = @vehicle.tracking_points.create!(
      lat: 50.0, lng: 0.0, recorded_at: Time.current
    )
    result = DeviationCheckService.check(point)
    assert_nil result
  end

  test "cross_track_distance returns correct distance for perpendicular point" do
    # A simple east-west line and a point offset north
    seg_start = [ 0.0, 0.0 ]  # [lng, lat]
    seg_end = [ 1.0, 0.0 ]
    # Point at (0, 0.5) — should be ~55.6km north
    dist = DeviationCheckService.cross_track_distance(0.5, 0.5, seg_start, seg_end)
    assert_in_delta 55_600, dist, 500
  end

  test "check handles invalid JSON in planned_path" do
    @vehicle.update_column(:planned_path, "not json at all")
    point = @vehicle.tracking_points.create!(
      lat: 50.0, lng: 0.0, recorded_at: Time.current
    )
    result = DeviationCheckService.check(point)
    assert_nil result
  end

  test "check handles path with null geometry" do
    @vehicle.update_column(:planned_path, '{"type":"Feature","geometry":null}')
    point = @vehicle.tracking_points.create!(
      lat: 50.0, lng: 0.0, recorded_at: Time.current
    )
    result = DeviationCheckService.check(point)
    assert_nil result
  end

  test "minimum_distance_to_path handles duplicate consecutive points" do
    path = [ [ -74.006, 40.7128 ], [ -74.006, 40.7128 ], [ -73.98, 40.73 ] ]
    dist = DeviationCheckService.minimum_distance_to_path(40.7128, -74.006, path)
    assert_in_delta 0, dist, 1.0
  end

  test "minimum_distance_to_path for point at mid-segment endpoint" do
    path = [ [ -74.006, 40.7128 ], [ -73.99, 40.72 ], [ -73.98, 40.73 ] ]
    # Point exactly at second coordinate
    dist = DeviationCheckService.minimum_distance_to_path(40.72, -73.99, path)
    assert_in_delta 0, dist, 1.0
  end

  test "check handles bare LineString type (not wrapped in Feature)" do
    @vehicle.update!(planned_path: '{"type":"LineString","coordinates":[[-74.006,40.7128],[-73.99,40.72],[-73.98,40.73]]}')
    point = @vehicle.tracking_points.create!(
      lat: 40.7128, lng: -74.006, recorded_at: Time.current
    )
    result = DeviationCheckService.check(point)
    assert_nil result
  end

  test "alert message includes distance and units" do
    point = @vehicle.tracking_points.create!(
      lat: 40.80, lng: -73.90, recorded_at: Time.current
    )
    alert = DeviationCheckService.check(point)
    assert_match(/\d+\.\d+m/, alert.message)
    assert_match(/deviated/, alert.message.downcase)
  end
end
