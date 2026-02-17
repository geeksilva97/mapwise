require "test_helper"

class MapwiseErrorTest < ActiveSupport::TestCase
  test "inherits from StandardError" do
    assert MapwiseError < StandardError
  end

  test "can be raised with just a message" do
    error = MapwiseError.new("something broke")
    assert_equal "something broke", error.message
    assert_equal({}, error.context)
  end

  test "carries a context hash" do
    error = MapwiseError.new("fail", context: { import_id: 42, row: 5 })
    assert_equal({ import_id: 42, row: 5 }, error.context)
  end

  test "context defaults to empty hash" do
    error = MapwiseError.new
    assert_equal({}, error.context)
  end

  # --- Hierarchy ---

  test "ImportError inherits from MapwiseError" do
    assert ImportError < MapwiseError
  end

  test "UnsupportedFileFormatError inherits from ImportError" do
    assert UnsupportedFileFormatError < ImportError
  end

  test "GeocodeError inherits from MapwiseError" do
    assert GeocodeError < MapwiseError
  end

  test "AiChatError inherits from MapwiseError" do
    assert AiChatError < MapwiseError
  end

  test "ToolCallLimitExceededError inherits from AiChatError" do
    assert ToolCallLimitExceededError < AiChatError
  end

  test "FileParseError inherits from MapwiseError" do
    assert FileParseError < MapwiseError
  end

  # --- All domain errors are caught by rescue StandardError ---

  test "domain errors are caught by rescue StandardError" do
    caught = false
    begin
      raise ImportError.new("test", context: { id: 1 })
    rescue StandardError
      caught = true
    end
    assert caught
  end

  test "domain errors carry context through rescue" do
    begin
      raise ToolCallLimitExceededError.new("limit hit", context: { map_id: 7 })
    rescue MapwiseError => e
      assert_equal({ map_id: 7 }, e.context)
      assert_equal "limit hit", e.message
    end
  end
end
