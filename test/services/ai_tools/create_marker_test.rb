require "test_helper"

class AiTools::CreateMarkerTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
  end

  test "creates marker with required params" do
    result = AiTools::CreateMarker.new.execute(map_id: @map.id, lat: 40.7, lng: -74.0)

    assert result[:success]
    assert result[:marker_id]
    marker = Marker.find(result[:marker_id])
    assert_in_delta 40.7, marker.lat
    assert_in_delta(-74.0, marker.lng)
    assert_equal "#FF0000", marker.color
  end

  test "creates marker with all params" do
    result = AiTools::CreateMarker.new.execute(
      map_id: @map.id, lat: 40.7, lng: -74.0,
      title: "Cafe", description: "Nice place", color: "#3B82F6"
    )

    assert result[:success]
    marker = Marker.find(result[:marker_id])
    assert_equal "Cafe", marker.title
    assert_equal "Nice place", marker.description
    assert_equal "#3B82F6", marker.color
  end
end
