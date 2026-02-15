require "test_helper"

class DeviationCheckJobTest < ActiveJob::TestCase
  test "does not create alert when point is on path" do
    vehicle = tracked_vehicles(:courier_bike)
    point = vehicle.tracking_points.create!(
      lat: 40.7128, lng: -74.006, recorded_at: Time.current
    )

    assert_no_difference "DeviationAlert.count" do
      DeviationCheckJob.perform_now(point.id)
    end
  end

  test "creates alert and broadcasts when deviation detected" do
    vehicle = tracked_vehicles(:courier_bike)
    map = vehicle.map
    point = vehicle.tracking_points.create!(
      lat: 40.80, lng: -73.90, recorded_at: Time.current
    )

    assert_difference "DeviationAlert.count", 1 do
      assert_broadcasts("tracking_map_#{map.id}", 1) do
        DeviationCheckJob.perform_now(point.id)
      end
    end
  end

  test "broadcast payload includes alert data" do
    vehicle = tracked_vehicles(:courier_bike)
    map = vehicle.map
    point = vehicle.tracking_points.create!(
      lat: 40.80, lng: -73.90, recorded_at: Time.current
    )

    transmitted = capture_broadcasts("tracking_map_#{map.id}") do
      DeviationCheckJob.perform_now(point.id)
    end

    assert_equal 1, transmitted.size
    data = transmitted.first
    assert_equal "deviation_alert", data["type"]
    assert_equal vehicle.id, data["vehicle_id"]
    assert data["alert"]["distance_meters"] > 100
  end

  test "handles missing point gracefully" do
    assert_nothing_raised do
      DeviationCheckJob.perform_now(-1)
    end
  end

  test "skips when vehicle has no deviation detection" do
    vehicle = tracked_vehicles(:delivery_truck)
    point = vehicle.tracking_points.create!(
      lat: 50.0, lng: 0.0, recorded_at: Time.current
    )

    assert_no_difference "DeviationAlert.count" do
      DeviationCheckJob.perform_now(point.id)
    end
  end
end
