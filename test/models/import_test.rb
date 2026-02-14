require "test_helper"

class ImportTest < ActiveSupport::TestCase
  test "validates presence of file_name" do
    import = Import.new(map: maps(:one))
    assert_not import.valid?
    assert_includes import.errors[:file_name], "can't be blank"
  end

  test "validates status inclusion" do
    import = Import.new(map: maps(:one), file_name: "test.csv", status: "invalid")
    assert_not import.valid?
    assert_includes import.errors[:status], "is not included in the list"
  end

  test "valid with required attributes" do
    import = Import.new(map: maps(:one), file_name: "test.csv", status: "pending")
    assert import.valid?
  end

  test "belongs to map" do
    import = imports(:pending_import)
    assert_equal maps(:one), import.map
  end

  test "progress_percentage with zero total" do
    import = Import.new(total_rows: 0, processed_rows: 0)
    assert_equal 0, import.progress_percentage
  end

  test "progress_percentage calculation" do
    import = Import.new(total_rows: 10, processed_rows: 5)
    assert_equal 50, import.progress_percentage
  end

  test "completed?" do
    assert imports(:completed_import).completed?
    assert_not imports(:pending_import).completed?
  end

  test "failed?" do
    import = Import.new(status: "failed")
    assert import.failed?
  end

  test "processing?" do
    import = Import.new(status: "processing")
    assert import.processing?
  end

  test "error_log is deserialized as JSON" do
    import = imports(:completed_import)
    assert_kind_of Array, import.error_log
    assert_equal 2, import.error_log.size
    assert_equal 3, import.error_log.first["row"]
  end

  test "default status is pending" do
    import = Import.new
    assert_equal "pending", import.status
  end
end
