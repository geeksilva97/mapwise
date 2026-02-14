require "test_helper"

class MapStyleTest < ActiveSupport::TestCase
  test "validates presence of name" do
    style = MapStyle.new(style_json: "[]")
    assert_not style.valid?
    assert_includes style.errors[:name], "can't be blank"
  end

  test "validates presence of style_json" do
    style = MapStyle.new(name: "Test")
    assert_not style.valid?
    assert_includes style.errors[:style_json], "can't be blank"
  end

  test "system_presets scope returns only system defaults" do
    presets = MapStyle.system_presets
    assert presets.all?(&:system_default?)
    assert presets.count >= 2
  end

  test "for_user scope returns system presets and user styles" do
    user = users(:one)
    styles = MapStyle.for_user(user)
    assert styles.any?(&:system_default?)
    assert styles.any? { |s| s.user == user }
    assert styles.none? { |s| s.user == users(:two) }
  end

  test "user_id is optional for system presets" do
    style = MapStyle.new(name: "System", style_json: "[]", system_default: true)
    assert style.valid?
  end

  test "valid with all attributes" do
    style = MapStyle.new(user: users(:one), name: "Custom", style_json: '[{"test": true}]')
    assert style.valid?
  end
end
