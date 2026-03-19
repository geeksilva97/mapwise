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

  test "should limit points with limit parameter" do
    get points_map_tracked_vehicle_path(@map, @vehicle),
      params: { limit: 2 },
      as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert_equal 2, data.length
  end

  # SAVE PLANNED PATH - clear
  test "should clear planned path with null" do
    vehicle = tracked_vehicles(:courier_bike)
    assert vehicle.planned_path.present?
    patch save_planned_path_map_tracked_vehicle_path(@map, vehicle),
      params: { planned_path: nil },
      as: :json
    assert_response :success
    assert_nil vehicle.reload.planned_path
  end

  # POINTS - empty
  test "should return empty array when no points" do
    vehicle = tracked_vehicles(:inactive_van)
    get points_map_tracked_vehicle_path(@map, vehicle), as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert_equal [], data
  end

  # CLEAR POINTS - empty vehicle
  test "should handle clear points on vehicle with no points" do
    vehicle = tracked_vehicles(:inactive_van)
    delete clear_points_map_tracked_vehicle_path(@map, vehicle), as: :json
    assert_response :no_content
  end

  # CROSS-USER SECURITY
  test "should not update vehicle on other user map" do
    other_vehicle = tracked_vehicles(:other_vehicle)
    other_map = maps(:two)
    patch map_tracked_vehicle_path(other_map, other_vehicle),
      params: { tracked_vehicle: { name: "Hacked" } },
      as: :json
    assert_response :not_found
  end

  test "should not destroy vehicle on other user map" do
    other_vehicle = tracked_vehicles(:other_vehicle)
    other_map = maps(:two)
    assert_no_difference "TrackedVehicle.count" do
      delete map_tracked_vehicle_path(other_map, other_vehicle), as: :json
    end
    assert_response :not_found
  end

  test "should not toggle active on other user vehicle" do
    other_vehicle = tracked_vehicles(:other_vehicle)
    other_map = maps(:two)
    patch toggle_active_map_tracked_vehicle_path(other_map, other_vehicle), as: :json
    assert_response :not_found
  end

  test "should not access points on other user vehicle" do
    other_vehicle = tracked_vehicles(:other_vehicle)
    other_map = maps(:two)
    get points_map_tracked_vehicle_path(other_map, other_vehicle), as: :json
    assert_response :not_found
  end

  # TURBO STREAM responses
  test "should create vehicle via turbo_stream" do
    assert_difference "TrackedVehicle.count", 1 do
      post map_tracked_vehicles_path(@map),
        params: { tracked_vehicle: { name: "Stream Vehicle", color: "#10B981" } },
        as: :turbo_stream
    end
    assert_response :success
  end

  test "should create invalid vehicle via turbo_stream re-renders form" do
    assert_no_difference "TrackedVehicle.count" do
      post map_tracked_vehicles_path(@map),
        params: { tracked_vehicle: { name: "" } },
        as: :turbo_stream
    end
    assert_response :success
  end

  test "should update vehicle via turbo_stream" do
    patch map_tracked_vehicle_path(@map, @vehicle),
      params: { tracked_vehicle: { name: "TS Updated" } },
      as: :turbo_stream
    assert_response :success
    assert_equal "TS Updated", @vehicle.reload.name
  end

  test "should update invalid vehicle via turbo_stream re-renders form" do
    patch map_tracked_vehicle_path(@map, @vehicle),
      params: { tracked_vehicle: { name: "" } },
      as: :turbo_stream
    assert_response :success
  end

  test "should destroy vehicle via turbo_stream" do
    assert_difference "TrackedVehicle.count", -1 do
      delete map_tracked_vehicle_path(@map, @vehicle), as: :turbo_stream
    end
    assert_response :success
  end

  test "should toggle active via turbo_stream" do
    patch toggle_active_map_tracked_vehicle_path(@map, @vehicle), as: :turbo_stream
    assert_response :success
    assert_not @vehicle.reload.active?
  end

  test "should clear points via turbo_stream" do
    delete clear_points_map_tracked_vehicle_path(@map, @vehicle), as: :turbo_stream
    assert_response :success
    assert_equal 0, @vehicle.tracking_points.count
  end

  test "should save planned path via turbo_stream" do
    geojson = '{"type":"Feature","geometry":{"type":"LineString","coordinates":[[-74,40.7],[-73.9,40.8]]}}'
    patch save_planned_path_map_tracked_vehicle_path(@map, @vehicle),
      params: { planned_path: geojson },
      as: :turbo_stream
    assert_response :success
    assert_equal geojson, @vehicle.reload.planned_path
  end

  test "should edit vehicle via turbo_stream" do
    get edit_map_tracked_vehicle_path(@map, @vehicle), as: :turbo_stream
    assert_response :success
  end

  test "should edit vehicle via json" do
    get edit_map_tracked_vehicle_path(@map, @vehicle), as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert_equal @vehicle.name, data["name"]
  end

  # AUTH
  test "should require authentication" do
    sign_out
    post map_tracked_vehicles_path(@map),
      params: { tracked_vehicle: { name: "Test" } },
      as: :json
    assert_response :redirect
  end

  # STRONG PARAMS
  test "create ignores unpermitted params" do
    assert_difference "TrackedVehicle.count", 1 do
      post map_tracked_vehicles_path(@map),
        params: { tracked_vehicle: { name: "Safe Vehicle", map_id: 999, webhook_token: "hacked", active: false } },
        as: :json
    end

    vehicle = TrackedVehicle.last
    assert_equal @map.id, vehicle.map_id
    assert_not_equal "hacked", vehicle.webhook_token
  end

  test "save_planned_path ignores unpermitted params" do
    geojson = '{"type":"Feature","geometry":{"type":"LineString","coordinates":[[-74,40.7],[-73.9,40.8]]}}'
    patch save_planned_path_map_tracked_vehicle_path(@map, @vehicle),
      params: { planned_path: geojson, name: "Hacked", active: false },
      as: :json

    assert_response :success
    @vehicle.reload
    assert_equal geojson, @vehicle.planned_path
    assert_equal "Delivery Truck", @vehicle.name
    assert @vehicle.active?
  end
end
