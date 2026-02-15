require "test_helper"

class TrackingPointTest < ActiveSupport::TestCase
  setup do
    @point = tracking_points(:truck_point_one)
  end

  test "valid point" do
    assert @point.valid?
  end

  test "requires lat" do
    @point.lat = nil
    assert_not @point.valid?
  end

  test "requires lng" do
    @point.lng = nil
    assert_not @point.valid?
  end

  test "requires recorded_at" do
    @point.recorded_at = nil
    assert_not @point.valid?
  end

  test "validates lat range" do
    @point.lat = -91
    assert_not @point.valid?

    @point.lat = 91
    assert_not @point.valid?

    @point.lat = 45
    assert @point.valid?
  end

  test "validates lng range" do
    @point.lng = -181
    assert_not @point.valid?

    @point.lng = 181
    assert_not @point.valid?

    @point.lng = -74
    assert @point.valid?
  end

  test "validates speed non-negative" do
    @point.speed = -1
    assert_not @point.valid?

    @point.speed = 0
    assert @point.valid?
  end

  test "validates heading range" do
    @point.heading = -1
    assert_not @point.valid?

    @point.heading = 360
    assert_not @point.valid?

    @point.heading = 0
    assert @point.valid?

    @point.heading = 359.9
    assert @point.valid?
  end

  test "chronological scope" do
    vehicle = tracked_vehicles(:delivery_truck)
    points = vehicle.tracking_points.chronological
    assert_equal tracking_points(:truck_point_one), points.first
    assert_equal tracking_points(:truck_point_two), points.last
  end

  test "in_range scope" do
    vehicle = tracked_vehicles(:delivery_truck)
    points = vehicle.tracking_points.in_range(3.hours.ago, 90.minutes.ago)
    assert_includes points, tracking_points(:truck_point_one)
    assert_not_includes points, tracking_points(:truck_point_two)
  end
end
