require "test_helper"

class CsvImportJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "enqueues job" do
    assert_enqueued_with(job: CsvImportJob, args: [ 42 ]) do
      CsvImportJob.perform_later(42)
    end
  end

  test "processes import via service" do
    map = maps(:one)
    import = map.imports.create!(file_name: "test.csv", status: "processing")
    content = "lat,lng,title\n40.7,-74.0,NYC"
    io = StringIO.new(content)
    import.file.attach(io: io, filename: "test.csv", content_type: "text/csv")
    import.update!(column_mapping: { "lat" => "lat", "lng" => "lng", "title" => "title" })

    assert_difference("Marker.count", 1) do
      CsvImportJob.perform_now(import.id)
    end

    import.reload
    assert_equal "completed", import.status
  end

  test "marks import as failed on error" do
    map = maps(:one)
    import = map.imports.create!(file_name: "bad.csv", status: "processing")
    # No file attached, so it will fail

    CsvImportJob.perform_now(import.id)

    import.reload
    assert_equal "failed", import.status
    assert import.error_log.present?
  end
end
