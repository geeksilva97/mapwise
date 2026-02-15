require "test_helper"

class ImportServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @map = maps(:one)
  end

  test "processes CSV with lat/lng columns" do
    import = create_import_with_csv("lat,lng,title,color\n40.7,-74.0,NYC,#FF0000\n34.0,-118.2,LA,#3B82F6")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng", "title" => "title", "color" => "color" }, status: "processing")

    assert_difference("Marker.count", 2) do
      ImportService.new(import).process
    end

    import.reload
    assert_equal "completed", import.status
    assert_equal 2, import.success_count
    assert_equal 0, import.error_count
  end

  test "processes CSV with group column" do
    import = create_import_with_csv("lat,lng,title,group\n40.7,-74.0,NYC,Cafes\n34.0,-118.2,LA,Cafes")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng", "title" => "title", "group" => "group" }, status: "processing")

    assert_difference("MarkerGroup.count", 1) do
      ImportService.new(import).process
    end

    group = MarkerGroup.find_by(name: "Cafes", map: @map)
    assert_not_nil group
    assert_equal 2, group.markers.count
  end

  test "tracks errors per row" do
    import = create_import_with_csv("lat,lng,title\n999,-74.0,Bad Lat\n34.0,-118.2,LA")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng", "title" => "title" }, status: "processing")

    ImportService.new(import).process

    import.reload
    assert_equal "completed", import.status
    assert_equal 1, import.success_count
    assert_equal 1, import.error_count
    assert import.error_log.any? { |e| e["row"] == 2 }
  end

  test "normalizes color values" do
    import = create_import_with_csv("lat,lng,color\n40.7,-74.0,FF0000\n34.0,-118.2,#3B82F6")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng", "color" => "color" }, status: "processing")

    ImportService.new(import).process

    markers = @map.markers.order(:created_at).last(2)
    assert_equal "#FF0000", markers.first.color
    assert_equal "#3B82F6", markers.last.color
  end

  test "address-only enqueues geocode jobs" do
    # Give user an API key for geocoding
    import = create_import_with_csv("address,title\n123 Main St,Office\n456 Oak Ave,Home")
    import.update!(column_mapping: { "address" => "address", "title" => "title" }, status: "processing")

    assert_enqueued_jobs 2, only: GeocodeJob do
      ImportService.new(import).process
    end

    import.reload
    assert_equal "completed", import.status
    assert_equal 2, import.success_count
  end

  test "errors on rows with no lat/lng or address" do
    import = create_import_with_csv("title\nNYC\nLA")
    import.update!(column_mapping: { "title" => "title" }, status: "processing")

    ImportService.new(import).process

    import.reload
    assert_equal 0, import.success_count
    assert_equal 2, import.error_count
  end

  test "processes CSV with description column" do
    import = create_import_with_csv("lat,lng,title,description\n40.7,-74.0,NYC,A great city")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng", "title" => "title", "description" => "description" }, status: "processing")

    ImportService.new(import).process

    marker = @map.markers.order(:created_at).last
    assert_equal "A great city", marker.description
  end

  test "creates multiple groups with distinct colors" do
    import = create_import_with_csv("lat,lng,group\n40.7,-74.0,A\n34.0,-118.2,B\n41.8,-87.6,A")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng", "group" => "group" }, status: "processing")

    assert_difference("MarkerGroup.count", 2) do
      ImportService.new(import).process
    end

    group_a = MarkerGroup.find_by(name: "A", map: @map)
    group_b = MarkerGroup.find_by(name: "B", map: @map)
    assert_not_equal group_a.color, group_b.color
  end

  test "normalizes color without hash prefix" do
    import = create_import_with_csv("lat,lng,color\n40.7,-74.0,FF0000")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng", "color" => "color" }, status: "processing")

    ImportService.new(import).process

    marker = @map.markers.order(:created_at).last
    assert_equal "#FF0000", marker.color
  end

  test "ignores invalid color values and uses DB default" do
    import = create_import_with_csv("lat,lng,color\n40.7,-74.0,notacolor")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng", "color" => "color" }, status: "processing")

    ImportService.new(import).process

    marker = @map.markers.order(:created_at).last
    assert_equal "#FF0000", marker.color  # DB default since invalid color is ignored
  end

  test "group color overrides row color" do
    import = create_import_with_csv("lat,lng,color,group\n40.7,-74.0,#FF0000,Cafes")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng", "color" => "color", "group" => "group" }, status: "processing")

    ImportService.new(import).process

    marker = @map.markers.order(:created_at).last
    group = MarkerGroup.find_by(name: "Cafes", map: @map)
    assert_equal group.color, marker.color
  end

  test "marks import as failed on unexpected error" do
    import = create_import_with_csv("lat,lng\n40.7,-74.0")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng" }, status: "processing")

    # Simulate an error during process by using an invalid file
    import.file.purge

    assert_raises do
      ImportService.new(import).process
    end

    import.reload
    assert_equal "failed", import.status
  end

  test "address-only sets lat/lng to 0 and uses address as description" do
    import = create_import_with_csv("address,title\n123 Main St,Office")
    import.update!(column_mapping: { "address" => "address", "title" => "title" }, status: "processing")

    ImportService.new(import).process

    marker = @map.markers.order(:created_at).last
    assert_equal "Office", marker.title
    assert_equal "123 Main St", marker.description
    assert_in_delta 0.0, marker.lat, 0.001
    assert_in_delta 0.0, marker.lng, 0.001
  end

  private

  def create_import_with_csv(content)
    import = @map.imports.create!(file_name: "test.csv", status: "mapping")
    io = StringIO.new(content)
    import.file.attach(io: io, filename: "test.csv", content_type: "text/csv")
    import
  end
end
