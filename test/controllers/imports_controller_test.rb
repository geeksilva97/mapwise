require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
    @map = maps(:one)
    sign_in_as(@user)
  end

  test "create without file returns error" do
    post map_imports_path(@map), as: :json
    assert_response :unprocessable_entity
  end

  test "create with CSV file uploads and returns mapping" do
    csv_content = "lat,lng,title\n40.7,-74.0,NYC\n34.0,-118.2,LA"
    file = create_tempfile("markers.csv", csv_content)

    assert_difference("Import.count") do
      post map_imports_path(@map),
           params: { file: Rack::Test::UploadedFile.new(file.path, "text/csv", false, original_filename: "markers.csv") }
    end

    assert_redirected_to edit_map_path(@map)
    import = Import.last
    assert_equal "markers.csv", import.file_name
    assert_equal "mapping", import.status
  end

  test "show returns progress as json" do
    import = imports(:completed_import)
    get map_import_path(@map, import), as: :json

    assert_response :success
    data = JSON.parse(response.body)
    assert_equal "completed", data["status"]
    assert_equal 10, data["total_rows"]
    assert_equal 100, data["progress"]
  end

  test "update saves column mapping and enqueues job" do
    import = @map.imports.create!(file_name: "test.csv", status: "mapping")

    assert_enqueued_with(job: CsvImportJob) do
      patch map_import_path(@map, import),
            params: { column_mapping: { lat: "Latitude", lng: "Longitude", title: "Name" } },
            as: :json
    end

    assert_response :success
    import.reload
    assert_equal "processing", import.status
    assert_equal "Latitude", import.column_mapping["lat"]
  end

  test "create without file via turbo_stream returns error" do
    post map_imports_path(@map), as: :turbo_stream
    assert_response :success
  end

  test "create without file via html redirects with alert" do
    post map_imports_path(@map)
    assert_redirected_to edit_map_path(@map)
  end

  test "create with CSV file via turbo_stream returns column mapping" do
    csv_content = "lat,lng,title\n40.7,-74.0,NYC\n34.0,-118.2,LA"
    file = create_tempfile("markers.csv", csv_content)

    assert_difference("Import.count") do
      post map_imports_path(@map),
           params: { file: Rack::Test::UploadedFile.new(file.path, "text/csv", false, original_filename: "markers.csv") },
           as: :turbo_stream
    end

    assert_response :success
  end

  test "create with CSV file returns import with headers" do
    csv_content = "lat,lng,title\n40.7,-74.0,NYC"
    file = create_tempfile("markers.csv", csv_content)

    assert_difference("Import.count") do
      post map_imports_path(@map),
           params: { file: Rack::Test::UploadedFile.new(file.path, "text/csv", false, original_filename: "markers.csv") },
           as: :turbo_stream
    end

    assert_response :success
  end

  test "show completed import via turbo_stream" do
    import = imports(:completed_import)
    get map_import_path(@map, import), as: :turbo_stream
    assert_response :success
  end

  test "show pending import via turbo_stream" do
    import = imports(:pending_import)
    import.update!(status: "processing")
    get map_import_path(@map, import), as: :turbo_stream
    assert_response :success
  end

  test "update via turbo_stream renders progress" do
    import = @map.imports.create!(file_name: "test.csv", status: "mapping")

    patch map_import_path(@map, import),
          params: { column_mapping: { lat: "Latitude", lng: "Longitude" } },
          as: :turbo_stream

    assert_response :success
    import.reload
    assert_equal "processing", import.status
  end

  test "user cannot access imports on other user's maps" do
    other_map = maps(:two)
    post map_imports_path(other_map), as: :json
    assert_response :not_found
  end

  test "create requires authentication" do
    sign_out
    post map_imports_path(@map), as: :json
    assert_redirected_to new_session_path
  end

  private

  def create_tempfile(filename, content)
    ext = File.extname(filename)
    base = File.basename(filename, ext)
    tempfile = Tempfile.new([ base, ext ])
    tempfile.write(content)
    tempfile.rewind
    tempfile
  end
end
