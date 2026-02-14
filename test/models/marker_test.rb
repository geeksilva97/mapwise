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
end
