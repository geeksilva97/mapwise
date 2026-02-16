require "test_helper"

class AiTools::UpdateMapTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
  end

  test "updates map title" do
    result = AiTools::UpdateMap.new.execute(map_id: @map.id, title: "New Title")

    assert result[:success]
    @map.reload
    assert_equal "New Title", @map.title
  end

  test "updates center and zoom" do
    result = AiTools::UpdateMap.new.execute(map_id: @map.id, center_lat: 51.5, center_lng: -0.12, zoom: 15)

    assert result[:success]
    @map.reload
    assert_in_delta 51.5, @map.center_lat
    assert_in_delta(-0.12, @map.center_lng)
    assert_equal 15, @map.zoom
  end
end
