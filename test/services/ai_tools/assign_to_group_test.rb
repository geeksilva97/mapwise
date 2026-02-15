require "test_helper"

class AiTools::AssignToGroupTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
    @marker = markers(:two_on_one)
  end

  test "assigns markers to existing group" do
    group = marker_groups(:hotels)
    result = AiTools::AssignToGroup.execute(@map, {
      "marker_ids" => [@marker.id],
      "group_name" => "Hotels"
    })

    assert result[:success]
    assert_equal group.id, result[:group_id]
    @marker.reload
    assert_equal group.id, @marker.marker_group_id
  end

  test "creates new group if not found" do
    assert_difference("MarkerGroup.count") do
      result = AiTools::AssignToGroup.execute(@map, {
        "marker_ids" => [@marker.id],
        "group_name" => "New Group"
      })
      assert result[:success]
    end
  end

  test "ignores marker IDs from other maps" do
    other_marker = markers(:on_other_map)
    result = AiTools::AssignToGroup.execute(@map, {
      "marker_ids" => [other_marker.id],
      "group_name" => "Hotels"
    })

    assert result[:success]
    assert_equal 0, result[:assigned_count]
  end
end
