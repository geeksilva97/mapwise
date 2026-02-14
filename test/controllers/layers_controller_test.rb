require "test_helper"

class LayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @map = maps(:one)
    @layer = layers(:polygon_layer)
  end

  test "create via turbo_stream" do
    assert_difference("Layer.count", 1) do
      post map_layers_path(@map), params: {
        layer: { name: "New Polygon", layer_type: "polygon", geometry_data: '{"type":"Feature"}' }
      }, as: :turbo_stream
    end

    assert_response :success
  end

  test "create via json" do
    assert_difference("Layer.count", 1) do
      post map_layers_path(@map), params: {
        layer: { name: "New Line", layer_type: "line", geometry_data: '{"type":"Feature"}' }
      }, as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "New Line", json["name"]
    assert_equal "line", json["layer_type"]
  end

  test "create with invalid params" do
    assert_no_difference("Layer.count") do
      post map_layers_path(@map), params: {
        layer: { name: "", layer_type: "polygon", geometry_data: '{"type":"Feature"}' }
      }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end

  test "update via json with colors" do
    patch map_layer_path(@map, @layer), params: {
      layer: { name: "Renamed", stroke_color: "#FF0000", fill_color: "#00FF00" }
    }, as: :json

    assert_response :success
    @layer.reload
    assert_equal "Renamed", @layer.name
    assert_equal "#FF0000", @layer.stroke_color
    assert_equal "#00FF00", @layer.fill_color
  end

  test "update via turbo_stream" do
    patch map_layer_path(@map, @layer), params: {
      layer: { name: "Updated Name" }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "Updated Name", @layer.reload.name
  end

  test "update via json" do
    patch map_layer_path(@map, @layer), params: {
      layer: { stroke_color: "#FF0000", fill_opacity: 0.5 }
    }, as: :json

    assert_response :success
    @layer.reload
    assert_equal "#FF0000", @layer.stroke_color
    assert_equal 0.5, @layer.fill_opacity
  end

  test "destroy via turbo_stream" do
    assert_difference("Layer.count", -1) do
      delete map_layer_path(@map, @layer), as: :turbo_stream
    end

    assert_response :success
  end

  test "destroy via json" do
    assert_difference("Layer.count", -1) do
      delete map_layer_path(@map, @layer), as: :json
    end

    assert_response :no_content
  end

  test "toggle_visibility" do
    assert @layer.visible?

    patch toggle_visibility_map_layer_path(@map, @layer), as: :turbo_stream
    assert_response :success
    assert_not @layer.reload.visible?

    patch toggle_visibility_map_layer_path(@map, @layer), as: :turbo_stream
    assert_response :success
    assert @layer.reload.visible?
  end

  test "toggle_visibility via json" do
    patch toggle_visibility_map_layer_path(@map, @layer), as: :json
    assert_response :success
    assert_not @layer.reload.visible?
  end

  test "scoped to current user maps" do
    other_map = maps(:two)
    other_layer = layers(:on_other_map)

    delete map_layer_path(other_map, other_layer), as: :json
    assert_response :not_found
  end

  test "requires authentication" do
    sign_out
    post map_layers_path(@map), params: {
      layer: { name: "Test", layer_type: "polygon", geometry_data: "{}" }
    }, as: :json

    assert_response :redirect
  end
end
