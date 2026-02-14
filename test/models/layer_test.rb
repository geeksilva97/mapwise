require "test_helper"

class LayerTest < ActiveSupport::TestCase
  test "validates presence of name" do
    layer = Layer.new(map: maps(:one), layer_type: "polygon", geometry_data: "{}")
    assert_not layer.valid?
    assert_includes layer.errors[:name], "can't be blank"
  end

  test "validates presence of layer_type" do
    layer = Layer.new(map: maps(:one), name: "Test", geometry_data: "{}")
    assert_not layer.valid?
    assert_includes layer.errors[:layer_type], "can't be blank"
  end

  test "validates layer_type inclusion" do
    layer = Layer.new(map: maps(:one), name: "Test", layer_type: "invalid", geometry_data: "{}")
    assert_not layer.valid?
    assert_includes layer.errors[:layer_type], "is not included in the list"
  end

  test "validates presence of geometry_data" do
    layer = Layer.new(map: maps(:one), name: "Test", layer_type: "polygon")
    assert_not layer.valid?
    assert_includes layer.errors[:geometry_data], "can't be blank"
  end

  test "valid with all required attributes" do
    layer = Layer.new(map: maps(:one), name: "Test", layer_type: "polygon", geometry_data: '{"type":"Feature"}')
    assert layer.valid?
  end

  test "validates stroke_color hex format" do
    layer = Layer.new(map: maps(:one), name: "Test", layer_type: "polygon", geometry_data: "{}", stroke_color: "invalid")
    assert_not layer.valid?
    assert_includes layer.errors[:stroke_color], "is invalid"
  end

  test "valid hex stroke_color" do
    layer = Layer.new(map: maps(:one), name: "Test", layer_type: "polygon", geometry_data: "{}", stroke_color: "#FF5500")
    assert layer.valid?
  end

  test "blank stroke_color is allowed" do
    layer = Layer.new(map: maps(:one), name: "Test", layer_type: "polygon", geometry_data: "{}", stroke_color: "")
    assert layer.valid?
  end

  test "validates fill_color hex format" do
    layer = Layer.new(map: maps(:one), name: "Test", layer_type: "polygon", geometry_data: "{}", fill_color: "red")
    assert_not layer.valid?
    assert_includes layer.errors[:fill_color], "is invalid"
  end

  test "validates stroke_width range" do
    layer = Layer.new(map: maps(:one), name: "Test", layer_type: "polygon", geometry_data: "{}", stroke_width: 0)
    assert_not layer.valid?
    assert_includes layer.errors[:stroke_width], "must be greater than or equal to 1"

    layer.stroke_width = 21
    assert_not layer.valid?
    assert_includes layer.errors[:stroke_width], "must be less than or equal to 20"
  end

  test "validates fill_opacity range" do
    layer = Layer.new(map: maps(:one), name: "Test", layer_type: "polygon", geometry_data: "{}", fill_opacity: -0.1)
    assert_not layer.valid?

    layer.fill_opacity = 1.1
    assert_not layer.valid?
  end

  test "valid fill_opacity within range" do
    layer = Layer.new(map: maps(:one), name: "Test", layer_type: "polygon", geometry_data: "{}", fill_opacity: 0.5)
    assert layer.valid?
  end

  test "all layer types are valid" do
    Layer::LAYER_TYPES.each do |type|
      layer = Layer.new(map: maps(:one), name: "Test", layer_type: type, geometry_data: "{}")
      assert layer.valid?, "#{type} should be a valid layer_type"
    end
  end

  test "belongs to map" do
    layer = layers(:polygon_layer)
    assert_equal maps(:one), layer.map
  end

  test "ordered scope sorts by position" do
    layers = maps(:one).layers.ordered
    assert_equal [0, 1, 2], layers.map(&:position)
  end

  test "visible scope filters hidden layers" do
    visible = maps(:one).layers.visible
    assert visible.all?(&:visible?)
    assert_not_includes visible, layers(:hidden_layer)
  end

  test "auto-assigns position on create" do
    map = maps(:one)
    existing_count = map.layers.count

    layer = map.layers.create!(name: "New Layer", layer_type: "polygon", geometry_data: "{}")
    assert_equal existing_count, layer.position
  end

  test "does not override explicitly set position" do
    map = maps(:one)
    layer = map.layers.create!(name: "Positioned", layer_type: "polygon", geometry_data: "{}", position: 99)
    assert_equal 99, layer.position
  end

  test "geojson parses geometry_data" do
    layer = layers(:polygon_layer)
    geojson = layer.geojson
    assert_equal "Feature", geojson["type"]
    assert_equal "Polygon", geojson["geometry"]["type"]
  end

  test "geojson returns empty hash for invalid JSON" do
    layer = Layer.new(geometry_data: "not json")
    assert_equal({}, layer.geojson)
  end

  test "default visible is true" do
    layer = Layer.new
    assert layer.visible?
  end

  test "default stroke_color" do
    layer = Layer.new
    assert_equal "#3B82F6", layer.stroke_color
  end

  test "default fill_opacity" do
    layer = Layer.new
    assert_equal 0.3, layer.fill_opacity
  end
end
