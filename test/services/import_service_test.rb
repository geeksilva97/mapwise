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

  private

  def create_import_with_csv(content)
    import = @map.imports.create!(file_name: "test.csv", status: "mapping")
    io = StringIO.new(content)
    import.file.attach(io: io, filename: "test.csv", content_type: "text/csv")
    import
  end
end
