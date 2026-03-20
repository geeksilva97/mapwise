require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @map = maps(:one)
    sign_in_as(@user)
  end

  test "new renders form" do
    get new_map_path
    assert_response :success
    assert_select "h1", "New Map"
  end

  test "new requires authentication" do
    sign_out
    get new_map_path
    assert_redirected_to new_session_path
  end

  test "create saves map and redirects to edit" do
    assert_difference("Map.count") do
      post maps_path, params: { map: { title: "Road Trip 2026" } }
    end

    map = Map.last
    assert_equal "Road Trip 2026", map.title
    assert_equal @user, map.user
    assert_not_nil map.embed_token
    assert_redirected_to edit_map_path(map)
  end

  test "create with invalid params re-renders form" do
    assert_no_difference("Map.count") do
      post maps_path, params: { map: { title: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "show renders viewer" do
    get map_path(@map)
    assert_response :success
    assert_select "h1", @map.title
    assert_select "#map-canvas"
  end

  test "show requires authentication" do
    sign_out
    get map_path(@map)
    assert_redirected_to new_session_path
  end

  test "edit renders editor" do
    get edit_map_path(@map)
    assert_response :success
    assert_select "#map-canvas"
  end

  test "edit requires authentication and ownership" do
    sign_out
    get edit_map_path(@map)
    assert_redirected_to new_session_path
  end

  test "update saves changes via HTML" do
    patch map_path(@map), params: { map: { title: "Updated Title" } }
    assert_redirected_to edit_map_path(@map)

    @map.reload
    assert_equal "Updated Title", @map.title
  end

  test "update saves changes via JSON" do
    patch map_path(@map),
          params: { map: { center_lat: 40.0, center_lng: -74.0, zoom: 10 } },
          as: :json

    assert_response :ok
    @map.reload
    assert_in_delta 40.0, @map.center_lat, 0.001
    assert_in_delta(-74.0, @map.center_lng, 0.001)
    assert_equal 10, @map.zoom
  end

  test "destroy removes map and redirects" do
    assert_difference("Map.count", -1) do
      delete map_path(@map)
    end

    assert_redirected_to root_path
  end

  test "user cannot access other user's map" do
    other_map = maps(:two)
    get map_path(other_map)
    assert_response :not_found
  end

  test "user cannot edit other user's map" do
    other_map = maps(:two)
    get edit_map_path(other_map)
    assert_response :not_found
  end

  test "user cannot update other user's map" do
    other_map = maps(:two)
    patch map_path(other_map), params: { map: { title: "Hacked" } }
    assert_response :not_found
  end

  test "user cannot delete other user's map" do
    other_map = maps(:two)
    assert_no_difference("Map.count") do
      delete map_path(other_map)
    end
    assert_response :not_found
  end

  test "update saves settings via turbo_stream" do
    patch map_path(@map),
          params: { map: { title: "Stream Title" } },
          as: :turbo_stream

    assert_response :success
    @map.reload
    assert_equal "Stream Title", @map.title
  end

  test "new map gets US-center defaults on create" do
    post maps_path, params: { map: { title: "Defaults Test" } }
    map = Map.last
    assert_in_delta 39.8283, map.center_lat, 0.0001
    assert_in_delta(-98.5795, map.center_lng, 0.0001)
    assert_equal 4, map.zoom
  end

  # Dual-mode rendering: JSON styles vs cloud Map ID

  test "editor renders style-json data attribute for map with JSON styles" do
    styled = maps(:styled_map)
    get edit_map_path(styled)
    assert_response :success
    assert_select "#map-canvas[data-map-style-json-value]"
    assert_select "#map-canvas[data-map-google-map-id-value]", count: 0
  end

  test "editor renders google-map-id data attribute for cloud-styled map" do
    cloud = maps(:cloud_styled_map)
    get edit_map_path(cloud)
    assert_response :success
    assert_select "#map-canvas[data-map-google-map-id-value='abc123def456']"
  end

  test "viewer renders style-json data attribute for map with JSON styles" do
    styled = maps(:styled_map)
    get map_path(styled)
    assert_response :success
    assert_select "#map-canvas[data-map-style-json-value]"
    assert_select "#map-canvas[data-map-google-map-id-value]", count: 0
  end

  test "viewer renders google-map-id data attribute for cloud-styled map" do
    cloud = maps(:cloud_styled_map)
    get map_path(cloud)
    assert_response :success
    assert_select "#map-canvas[data-map-google-map-id-value='abc123def456']"
  end

  test "editor omits both style attrs for plain map" do
    get edit_map_path(@map)
    assert_response :success
    assert_select "#map-canvas[data-map-style-json-value]", count: 0
    assert_select "#map-canvas[data-map-google-map-id-value]", count: 0
  end

  # Sharing UI

  test "editor shows sharing section with unchecked toggle for private map" do
    get edit_map_path(@map)
    assert_response :success
    assert_select "[data-controller='share']"
    assert_select "input[data-share-target='toggle']:not([checked])"
    assert_select "[data-share-target='embedSection'].hidden"
  end

  test "editor shows sharing section with checked toggle for public map" do
    public_map = maps(:public_map)
    get edit_map_path(public_map)
    assert_response :success
    assert_select "input[data-share-target='toggle'][checked]"
  end

  test "editor shows embed code when map is public and user has API key" do
    public_map = maps(:public_map)
    get edit_map_path(public_map)
    assert_response :success
    assert_select "input[data-share-target='embedCode']"
    assert_select "input[data-share-target='directLink']"
  end

  test "editor shows API key warning when public but no API key" do
    @user.api_keys.destroy_all
    public_map = maps(:public_map)
    get edit_map_path(public_map)
    assert_response :success
    assert_select "[data-share-target='embedSection']" do
      assert_select "a[href='#{settings_path(tab: "google maps")}']"
    end
  end

  test "toggling public via JSON updates map visibility" do
    assert_not @map.public?
    patch map_path(@map),
          params: { map: { public: true } },
          as: :json
    assert_response :ok
    @map.reload
    assert @map.public?
  end

  # Clustering

  test "update saves clustering_enabled" do
    assert_not @map.clustering_enabled?
    patch map_path(@map),
          params: { map: { clustering_enabled: true } },
          as: :json
    assert_response :ok
    @map.reload
    assert @map.clustering_enabled?
  end

  test "editor renders clustering data attribute" do
    get edit_map_path(@map)
    assert_response :success
    assert_select "#map-canvas[data-map-clustering-enabled-value='false']"
  end

  test "editor renders clustering data attribute when enabled" do
    @map.update!(clustering_enabled: true)
    get edit_map_path(@map)
    assert_response :success
    assert_select "#map-canvas[data-map-clustering-enabled-value='true']"
  end

  # Search

  test "update saves search_enabled and search_mode" do
    patch map_path(@map),
          params: { map: { search_enabled: true, search_mode: "markers" } },
          as: :turbo_stream

    assert_response :success
    @map.reload
    assert @map.search_enabled?
    assert_equal "markers", @map.search_mode
  end

  test "viewer renders search overlay when search enabled" do
    public_map = maps(:public_map)
    assert public_map.search_enabled?
    get map_path(public_map)
    assert_response :success
    assert_select "[data-controller='map-search']"
  end

  test "viewer hides search overlay when search disabled" do
    get map_path(@map)
    assert_response :success
    assert_select "[data-controller='map-search']", count: 0
  end

  test "editor does not render search overlay" do
    public_map = maps(:public_map)
    get edit_map_path(public_map)
    assert_response :success
    assert_select "[data-controller='map-search']", count: 0
  end

  # Tracking

  test "tracking page renders" do
    get tracking_map_path(@map)
    assert_response :success
    assert_select "h1", /Tracking/
    assert_select "[data-controller='tracking']"
  end

  test "tracking page requires auth" do
    sign_out
    get tracking_map_path(@map)
    assert_redirected_to new_session_path
  end

  test "tracking page 404s for other user map" do
    other_map = maps(:two)
    get tracking_map_path(other_map)
    assert_response :not_found
  end

  test "editor shows tracking tab" do
    get edit_map_path(@map)
    assert_response :success
    assert_select "button", text: "Tracking"
  end

  # Update failures

  test "update with invalid params via turbo_stream re-renders form" do
    patch map_path(@map),
          params: { map: { title: "" } },
          as: :turbo_stream

    assert_response :success
    assert_equal @map.reload.title, maps(:one).title
  end

  test "update with invalid params via json returns errors" do
    patch map_path(@map),
          params: { map: { title: "" } },
          as: :json

    assert_response :unprocessable_entity
  end

  test "update with invalid params via html re-renders edit" do
    patch map_path(@map),
          params: { map: { title: "" } }

    assert_response :unprocessable_entity
  end

  test "destroy requires ownership" do
    other_map = maps(:two)
    assert_no_difference("Map.count") do
      delete map_path(other_map)
    end
    assert_response :not_found
  end

  # Double-click focus wiring

  test "editor marker items have dblclick focus action and select-none" do
    get edit_map_path(@map)
    assert_response :success

    marker = markers(:two_on_one)
    assert_select "#marker_#{marker.id} [data-action='dblclick->marker-editor#focusMarker']" do |elements|
      el = elements.first
      assert_includes el["class"], "select-none"
      assert_equal marker.id.to_s, el["data-marker-id"]
    end
  end

  test "editor layer items have dblclick focus action and select-none" do
    get edit_map_path(@map)
    assert_response :success

    layer = layers(:polygon_layer)
    assert_select "#layer_#{layer.id} [data-action='dblclick->marker-editor#focusLayer']" do |elements|
      el = elements.first
      assert_includes el["class"], "select-none"
      assert_equal layer.id.to_s, el["data-layer-id"]
    end
  end

  test "editor renders global confirm dialog" do
    get edit_map_path(@map)
    assert_response :success
    assert_select "dialog[data-confirm-dialog-target='dialog']"
  end

  test "editor chat clear button uses confirm dialog" do
    get edit_map_path(@map)
    assert_response :success

    assert_select "button[data-action='click->confirm-dialog#open'][data-confirm-form='#clear_chat_#{@map.id}']"
    assert_select "form#clear_chat_#{@map.id}[class='hidden']"
  end

  test "editor renders import button in markers header" do
    get edit_map_path(@map)
    assert_response :success
    assert_select "button[data-action='click->import-dialog#open']", text: "Import"
  end

  test "editor renders import dialog with upload form" do
    get edit_map_path(@map)
    assert_response :success
    assert_select "dialog[data-import-dialog-target='dialog']" do
      assert_select "h3", text: "Import Markers"
      assert_select "div[data-import-dialog-target='body']" do
        assert_select "form[data-action='submit->import#upload']"
        assert_select "input[type='file'][accept='.csv,.xlsx,.xls']"
      end
    end
  end

  test "editor import dialog has template for reset" do
    get edit_map_path(@map)
    assert_response :success
    assert_select "template[data-import-dialog-target='initialContent']"
  end

  test "editor does not render old inline import section" do
    get edit_map_path(@map)
    assert_response :success
    # The old import section had an "Import" heading inside a border-t section at the bottom
    assert_select "div[data-tabs-target='panel']" do
      assert_select "p.uppercase", text: "Import", count: 0
    end
  end
end
