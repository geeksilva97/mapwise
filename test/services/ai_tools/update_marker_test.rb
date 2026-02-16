require "test_helper"

class AiTools::UpdateMarkerTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
    @marker = markers(:one)
  end

  test "updates marker title" do
    result = AiTools::UpdateMarker.new.execute(map_id: @map.id, marker_id: @marker.id, title: "New Title")

    assert result[:success]
    @marker.reload
    assert_equal "New Title", @marker.title
  end

  test "updates multiple fields" do
    result = AiTools::UpdateMarker.new.execute(
      map_id: @map.id, marker_id: @marker.id, title: "Updated", color: "#00FF00", lat: 41.0
    )

    assert result[:success]
    @marker.reload
    assert_equal "Updated", @marker.title
    assert_equal "#00FF00", @marker.color
    assert_in_delta 41.0, @marker.lat
  end

  test "raises for marker on other map" do
    other_marker = markers(:on_other_map)
    assert_raises(ActiveRecord::RecordNotFound) do
      AiTools::UpdateMarker.new.execute(map_id: @map.id, marker_id: other_marker.id, title: "Hack")
    end
  end
end
