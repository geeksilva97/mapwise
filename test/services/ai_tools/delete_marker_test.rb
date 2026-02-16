require "test_helper"

class AiTools::DeleteMarkerTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
    @marker = markers(:one)
  end

  test "deletes marker" do
    assert_difference("Marker.count", -1) do
      result = AiTools::DeleteMarker.new.execute(map_id: @map.id, marker_id: @marker.id)
      assert result[:success]
    end
  end

  test "raises for marker on other map" do
    other_marker = markers(:on_other_map)
    assert_raises(ActiveRecord::RecordNotFound) do
      AiTools::DeleteMarker.new.execute(map_id: @map.id, marker_id: other_marker.id)
    end
  end
end
