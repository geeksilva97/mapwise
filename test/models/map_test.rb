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
    assert_in_delta 39.8283, map.center_lat, 0.0001
    assert_in_delta(-98.5795, map.center_lng, 0.0001)
    assert_equal 4, map.zoom
    assert_equal "roadmap", map.map_type
    assert_equal false, map.public
    assert_equal false, map.clustering_enabled
  end

  test "find_public_by_token returns public map" do
    public_map = maps(:public_map)
    found = Map.find_public_by_token(public_map.embed_token)
    assert_equal public_map, found
  end

  test "find_public_by_token returns nil for private map" do
    private_map = maps(:one)
    assert_nil Map.find_public_by_token(private_map.embed_token)
  end

  test "find_public_by_token returns nil for invalid token" do
    assert_nil Map.find_public_by_token("nonexistent_token")
  end

  test "embed_api_key returns user's first API key" do
    map = maps(:one)
    expected_key = api_keys(:one).google_maps_key
    assert_equal expected_key, map.embed_api_key
  end

  test "embed_api_key returns nil when user has no API keys" do
    map = maps(:one)
    map.user.api_keys.destroy_all
    assert_nil map.embed_api_key
  end

  test "search_mode validates inclusion" do
    map = maps(:one)
    map.search_mode = "places"
    assert map.valid?

    map.search_mode = "markers"
    assert map.valid?

    map.search_mode = "invalid"
    assert_not map.valid?
    assert_includes map.errors[:search_mode], "is not included in the list"
  end

  test "search_enabled defaults to false" do
    map = Map.new(user: users(:one), title: "Search Test")
    assert_equal false, map.search_enabled
  end

  test "search_mode defaults to places" do
    map = Map.new(user: users(:one), title: "Search Test")
    assert_equal "places", map.search_mode
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

  test "has many marker_groups" do
    map = maps(:one)
    assert_respond_to map, :marker_groups
    assert map.marker_groups.count >= 1
  end

  test "destroys marker_groups on destroy" do
    map = maps(:one)
    group_count = map.marker_groups.count
    assert group_count > 0

    assert_difference("MarkerGroup.count", -group_count) do
      map.destroy
    end
  end

  test "destroys markers on destroy" do
    map = maps(:one)
    marker_count = map.markers.count
    assert marker_count > 0

    assert_difference("Marker.count", -marker_count) do
      map.destroy
    end
  end

  test "has many layers" do
    map = maps(:one)
    assert_respond_to map, :layers
    assert map.layers.count >= 1
  end

  test "destroys layers on destroy" do
    map = maps(:one)
    layer_count = map.layers.count
    assert layer_count > 0

    assert_difference("Layer.count", -layer_count) do
      map.destroy
    end
  end
end
