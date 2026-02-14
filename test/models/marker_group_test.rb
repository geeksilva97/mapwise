require "test_helper"

class MarkerGroupTest < ActiveSupport::TestCase
  test "validates presence of name" do
    group = MarkerGroup.new(map: maps(:one))
    assert_not group.valid?
    assert_includes group.errors[:name], "can't be blank"
  end

  test "valid with required attributes" do
    group = MarkerGroup.new(map: maps(:one), name: "Test Group")
    assert group.valid?
  end

  test "validates color format" do
    group = MarkerGroup.new(map: maps(:one), name: "Test", color: "invalid")
    assert_not group.valid?
    assert_includes group.errors[:color], "is invalid"
  end

  test "valid hex color passes validation" do
    group = MarkerGroup.new(map: maps(:one), name: "Test", color: "#FF5500")
    assert group.valid?
  end

  test "blank color is allowed" do
    group = MarkerGroup.new(map: maps(:one), name: "Test", color: "")
    assert group.valid?
  end

  test "belongs to map" do
    group = marker_groups(:restaurants)
    assert_equal maps(:one), group.map
  end

  test "has many markers" do
    group = marker_groups(:restaurants)
    assert_includes group.markers, markers(:one)
  end

  test "nullifies markers on destroy" do
    group = marker_groups(:restaurants)
    marker = markers(:one)
    assert_equal group, marker.marker_group

    group.destroy
    marker.reload
    assert_nil marker.marker_group_id
  end

  test "ordered scope sorts by position" do
    groups = maps(:one).marker_groups.ordered
    assert_equal [ 0, 1, 2 ], groups.map(&:position)
  end

  test "visible scope filters hidden groups" do
    visible = maps(:one).marker_groups.visible
    assert visible.all?(&:visible?)
    assert_not_includes visible, marker_groups(:hidden)
  end

  test "auto-assigns position on create" do
    map = maps(:one)
    existing_count = map.marker_groups.count

    group = map.marker_groups.create!(name: "New Group")
    assert_equal existing_count, group.position
  end

  test "does not override explicitly set position" do
    map = maps(:one)
    group = map.marker_groups.create!(name: "Positioned", position: 99)
    assert_equal 99, group.position
  end

  test "default color is gray" do
    group = MarkerGroup.new
    assert_equal "#6B7280", group.color
  end

  test "default visible is true" do
    group = MarkerGroup.new
    assert group.visible?
  end
end
