require "test_helper"

class TrackedVehiclesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @map = maps(:one)
    @vehicle = tracked_vehicles(:delivery_truck)
  end

  # CREATE
  test "should create vehicle" do
    assert_difference "TrackedVehicle.count", 1 do
      post map_tracked_vehicles_path(@map),
        params: { tracked_vehicle: { name: "New Vehicle", color: "#10B981" } },
        as: :json
    end
    assert_response :created
    data = JSON.parse(response.body)
    assert_equal "New Vehicle", data["name"]
    assert_not_nil data["webhook_token"]
    assert_not_nil data["webhook_url"]
  end

  test "should not create vehicle with invalid params" do
    assert_no_difference "TrackedVehicle.count" do
      post map_tracked_vehicles_path(@map),
        params: { tracked_vehicle: { name: "" } },
        as: :json
    end
    assert_response :unprocessable_entity
  end

  test "should not create vehicle for other user map" do
    other_map = maps(:two)
    post map_tracked_vehicles_path(other_map),
      params: { tracked_vehicle: { name: "Intruder" } },
      as: :json
    assert_response :not_found
  end

  # UPDATE
  test "should update vehicle" do
    patch map_tracked_vehicle_path(@map, @vehicle),
      params: { tracked_vehicle: { name: "Updated Truck" } },
      as: :json
    assert_response :success
    assert_equal "Updated Truck", @vehicle.reload.name
  end

  test "should not update with invalid params" do
    patch map_tracked_vehicle_path(@map, @vehicle),
      params: { tracked_vehicle: { name: "" } },
      as: :json
    assert_response :unprocessable_entity
  end

  # DESTROY
  test "should destroy vehicle" do
    assert_difference "TrackedVehicle.count", -1 do
      delete map_tracked_vehicle_path(@map, @vehicle), as: :json
    end
    assert_response :no_content
  end

  # TOGGLE ACTIVE
  test "should toggle active" do
    assert @vehicle.active?
    patch toggle_active_map_tracked_vehicle_path(@map, @vehicle), as: :json
    assert_response :success
    assert_not @vehicle.reload.active?
  end

  # CLEAR POINTS
  test "should clear tracking points" do
    assert @vehicle.tracking_points.any?
    delete clear_points_map_tracked_vehicle_path(@map, @vehicle), as: :json
    assert_response :no_content
    assert_equal 0, @vehicle.tracking_points.count
  end

  # SAVE PLANNED PATH
  test "should save planned path" do
    geojson = '{"type":"Feature","geometry":{"type":"LineString","coordinates":[[-74,40.7],[-73.9,40.8]]}}'
    patch save_planned_path_map_tracked_vehicle_path(@map, @vehicle),
      params: { planned_path: geojson },
      as: :json
    assert_response :success
    assert_equal geojson, @vehicle.reload.planned_path
  end

  # POINTS (history)
  test "should return tracking points as json" do
    get points_map_tracked_vehicle_path(@map, @vehicle), as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert_kind_of Array, data
    assert data.length > 0
    assert data.first.key?("lat")
    assert data.first.key?("lng")
  end

  test "should filter points by date range" do
    get points_map_tracked_vehicle_path(@map, @vehicle),
      params: { from: 3.hours.ago.iso8601, to: 90.minutes.ago.iso8601 },
      as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert_equal 1, data.length
  end

  # AUTH
  test "should require authentication" do
    sign_out
    post map_tracked_vehicles_path(@map),
      params: { tracked_vehicle: { name: "Test" } },
      as: :json
    assert_response :redirect
  end
end
