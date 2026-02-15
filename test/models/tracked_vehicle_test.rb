require "test_helper"

class TrackedVehicleTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
    @vehicle = tracked_vehicles(:delivery_truck)
  end

  test "valid vehicle" do
    assert @vehicle.valid?
  end

  test "requires name" do
    @vehicle.name = nil
    assert_not @vehicle.valid?
    assert_includes @vehicle.errors[:name], "can't be blank"
  end

  test "requires webhook_token" do
    @vehicle.webhook_token = nil
    assert_not @vehicle.valid?
  end

  test "webhook_token must be unique" do
    new_vehicle = @map.tracked_vehicles.build(name: "Duplicate", webhook_token: @vehicle.webhook_token)
    assert_not new_vehicle.valid?
    assert_includes new_vehicle.errors[:webhook_token], "has already been taken"
  end

  test "auto-generates webhook_token on create" do
    vehicle = @map.tracked_vehicles.build(name: "New Vehicle")
    assert_nil vehicle.webhook_token
    vehicle.save!
    assert_not_nil vehicle.webhook_token
  end

  test "validates color format" do
    @vehicle.color = "invalid"
    assert_not @vehicle.valid?

    @vehicle.color = "#3B82F6"
    assert @vehicle.valid?
  end

  test "validates deviation_threshold_meters positive" do
    @vehicle.deviation_threshold_meters = -10
    assert_not @vehicle.valid?

    @vehicle.deviation_threshold_meters = 0
    assert_not @vehicle.valid?

    @vehicle.deviation_threshold_meters = 100
    assert @vehicle.valid?
  end

  test "deviation_detection_enabled? requires both path and threshold" do
    vehicle = tracked_vehicles(:delivery_truck)
    assert_not vehicle.deviation_detection_enabled?

    vehicle = tracked_vehicles(:courier_bike)
    assert vehicle.deviation_detection_enabled?
  end

  test "ordered scope" do
    vehicles = @map.tracked_vehicles.ordered
    assert_equal vehicles.first.position, 0
  end

  test "active scope" do
    active = @map.tracked_vehicles.active
    assert active.all?(&:active?)
    assert_not_includes active, tracked_vehicles(:inactive_van)
  end

  test "last_tracking_point returns most recent" do
    last = @vehicle.last_tracking_point
    assert_equal tracking_points(:truck_point_two), last
  end

  test "assigns position on create" do
    count = @map.tracked_vehicles.count
    vehicle = @map.tracked_vehicles.create!(name: "Another")
    assert_equal count, vehicle.position
  end

  test "destroying vehicle destroys tracking points and alerts" do
    vehicle = tracked_vehicles(:courier_bike)
    point_count = vehicle.tracking_points.count
    alert_count = vehicle.deviation_alerts.count
    assert point_count > 0
    assert alert_count > 0
    assert_difference "TrackingPoint.count", -point_count do
      assert_difference "DeviationAlert.count", -alert_count do
        vehicle.destroy!
      end
    end
  end
end
