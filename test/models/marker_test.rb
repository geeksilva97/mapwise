require "test_helper"

class MarkerTest < ActiveSupport::TestCase
  test "validates presence of lat" do
    marker = Marker.new(map: maps(:one), lng: -74.0)
    assert_not marker.valid?
    assert_includes marker.errors[:lat], "can't be blank"
  end

  test "validates presence of lng" do
    marker = Marker.new(map: maps(:one), lat: 40.7)
    assert_not marker.valid?
    assert_includes marker.errors[:lng], "can't be blank"
  end

  test "belongs to map" do
    marker = markers(:one)
    assert_equal maps(:one), marker.map
  end

  test "default color is red" do
    marker = Marker.new
    assert_equal "#FF0000", marker.color
  end

  test "default position is 0" do
    marker = Marker.new
    assert_equal 0, marker.position
  end

  test "valid with required attributes" do
    marker = Marker.new(map: maps(:one), lat: 40.7, lng: -74.0)
    assert marker.valid?
  end

  # Lat/lng bounds validations
  test "lat must be >= -90" do
    marker = Marker.new(map: maps(:one), lat: -91, lng: 0)
    assert_not marker.valid?
    assert_includes marker.errors[:lat], "must be greater than or equal to -90"
  end

  test "lat must be <= 90" do
    marker = Marker.new(map: maps(:one), lat: 91, lng: 0)
    assert_not marker.valid?
    assert_includes marker.errors[:lat], "must be less than or equal to 90"
  end

  test "lng must be >= -180" do
    marker = Marker.new(map: maps(:one), lat: 0, lng: -181)
    assert_not marker.valid?
    assert_includes marker.errors[:lng], "must be greater than or equal to -180"
  end

  test "lng must be <= 180" do
    marker = Marker.new(map: maps(:one), lat: 0, lng: 181)
    assert_not marker.valid?
    assert_includes marker.errors[:lng], "must be less than or equal to 180"
  end

  # Color format validation
  test "valid hex color passes validation" do
    marker = Marker.new(map: maps(:one), lat: 40.0, lng: -74.0, color: "#3B82F6")
    assert marker.valid?
  end

  test "invalid color format fails validation" do
    marker = Marker.new(map: maps(:one), lat: 40.0, lng: -74.0, color: "red")
    assert_not marker.valid?
    assert_includes marker.errors[:color], "is invalid"
  end

  test "blank color is allowed" do
    marker = Marker.new(map: maps(:one), lat: 40.0, lng: -74.0, color: "")
    assert marker.valid?
  end

  # Auto-positioning
  test "auto-assigns position on create" do
    map = maps(:one)
    existing_count = map.markers.count

    marker = map.markers.create!(lat: 35.0, lng: -80.0)
    assert_equal existing_count, marker.position
  end

  test "does not override explicitly set position" do
    map = maps(:one)
    marker = map.markers.create!(lat: 35.0, lng: -80.0, position: 99)
    assert_equal 99, marker.position
  end
end
