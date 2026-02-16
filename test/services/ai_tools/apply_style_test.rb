require "test_helper"

class AiTools::ApplyStyleTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
  end

  test "applies Night style" do
    result = AiTools::ApplyStyle.new.execute(map_id: @map.id, style_name: "Night")

    assert result[:success]
    @map.reload
    assert_equal "Night", result[:style]
    assert_includes @map.style_json, "#242f3e"
  end

  test "applies Default style clears style_json" do
    @map.update!(style_json: "[{}]")
    result = AiTools::ApplyStyle.new.execute(map_id: @map.id, style_name: "Default")

    assert result[:success]
    @map.reload
    assert_nil @map.style_json
    assert_nil @map.google_map_id
  end

  test "returns error for unknown style" do
    result = AiTools::ApplyStyle.new.execute(map_id: @map.id, style_name: "Unknown")

    assert_not result[:success]
    assert_includes result[:error], "not found"
  end

  test "case-insensitive style matching" do
    result = AiTools::ApplyStyle.new.execute(map_id: @map.id, style_name: "night")

    assert result[:success]
    assert_equal "Night", result[:style]
  end
end
