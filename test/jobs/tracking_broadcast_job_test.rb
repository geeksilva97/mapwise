require "test_helper"

class TrackingBroadcastJobTest < ActiveJob::TestCase
  test "broadcasts point to correct channel" do
    point = tracking_points(:truck_point_one)
    vehicle = point.tracked_vehicle
    map = vehicle.map

    assert_broadcasts("tracking_map_#{map.id}", 1) do
      TrackingBroadcastJob.perform_now(point.id)
    end
  end

  test "broadcast payload includes expected fields" do
    point = tracking_points(:truck_point_one)
    vehicle = point.tracked_vehicle
    map = vehicle.map

    transmitted = capture_broadcasts("tracking_map_#{map.id}") do
      TrackingBroadcastJob.perform_now(point.id)
    end

    assert_equal 1, transmitted.size
    data = transmitted.first
    assert_equal "tracking_point", data["type"]
    assert_equal vehicle.id, data["vehicle_id"]
    assert_equal vehicle.name, data["vehicle_name"]
    assert_equal vehicle.color, data["vehicle_color"]
    assert_equal point.lat, data["point"]["lat"]
    assert_equal point.lng, data["point"]["lng"]
    assert_equal point.recorded_at.iso8601, data["point"]["recorded_at"]
  end

  test "handles missing point gracefully" do
    assert_nothing_raised do
      TrackingBroadcastJob.perform_now(-1)
    end
  end

  test "handles deleted point gracefully" do
    point_id = tracking_points(:truck_point_one).id
    TrackingPoint.find(point_id).destroy!

    assert_nothing_raised do
      TrackingBroadcastJob.perform_now(point_id)
    end
  end
end
