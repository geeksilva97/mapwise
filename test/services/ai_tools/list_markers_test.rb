require "test_helper"

class AiTools::ListMarkersTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
  end

  test "returns all markers on map" do
    result = AiTools::ListMarkers.new.execute(map_id: @map.id)

    assert result[:success]
    assert_equal @map.markers.count, result[:count]
    assert result[:markers].is_a?(Array)
  end

  test "includes marker details" do
    result = AiTools::ListMarkers.new.execute(map_id: @map.id)
    marker_data = result[:markers].find { |m| m[:id] == markers(:one).id }

    assert_equal "New York City", marker_data[:title]
    assert_in_delta 40.7128, marker_data[:lat]
    assert_equal "Restaurants", marker_data[:group]
  end
end
