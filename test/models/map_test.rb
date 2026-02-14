require "test_helper"

class MapTest < ActiveSupport::TestCase
  test "validates presence of title" do
    map = Map.new(user: users(:one))
    assert_not map.valid?
    assert_includes map.errors[:title], "can't be blank"
  end

  test "generates embed_token on create" do
    map = users(:one).maps.create!(title: "Token Test")
    assert_not_nil map.embed_token
    assert_equal 22, map.embed_token.length
  end

  test "embed_token is unique" do
    map1 = maps(:one)
    map2 = Map.new(user: users(:one), title: "Duplicate Token", embed_token: map1.embed_token)
    assert_not map2.valid?
    assert_includes map2.errors[:embed_token], "has already been taken"
  end

  test "belongs to user" do
    map = maps(:one)
    assert_equal users(:one), map.user
  end

  test "default values" do
    map = Map.new
    assert_equal 0.0, map.center_lat
    assert_equal 0.0, map.center_lng
    assert_equal 3, map.zoom
    assert_equal "roadmap", map.map_type
    assert_equal false, map.public
  end

  test "valid with all required attributes" do
    map = Map.new(user: users(:one), title: "Valid Map")
    assert map.valid?
  end

  test "has many markers" do
    map = maps(:one)
    assert_respond_to map, :markers
    assert map.markers.count >= 1
  end

  test "destroys markers on destroy" do
    map = maps(:one)
    marker_count = map.markers.count
    assert marker_count > 0

    assert_difference("Marker.count", -marker_count) do
      map.destroy
    end
  end
end
