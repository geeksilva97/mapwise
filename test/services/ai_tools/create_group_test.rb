require "test_helper"

class AiTools::CreateGroupTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
  end

  test "creates group with name" do
    result = AiTools::CreateGroup.new.execute(map_id: @map.id, name: "Cafes")

    assert result[:success]
    group = MarkerGroup.find(result[:group_id])
    assert_equal "Cafes", group.name
    assert_equal "#6B7280", group.color
  end

  test "creates group with custom color" do
    result = AiTools::CreateGroup.new.execute(map_id: @map.id, name: "Parks", color: "#22C55E")

    assert result[:success]
    group = MarkerGroup.find(result[:group_id])
    assert_equal "#22C55E", group.color
  end
end
