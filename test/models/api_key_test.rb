require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  test "validates presence of google_maps_key" do
    api_key = ApiKey.new(user: users(:one), workspace: workspaces(:one))
    assert_not api_key.valid?
    assert_includes api_key.errors[:google_maps_key], "can't be blank"
  end

  test "belongs to user" do
    api_key = api_keys(:one)
    assert_equal users(:one), api_key.user
  end

  test "encrypts and decrypts google_maps_key" do
    api_key = workspaces(:one).api_keys.create!(user: users(:one), google_maps_key: "AIzaSyNewTestKey999")
    api_key.reload
    assert_equal "AIzaSyNewTestKey999", api_key.google_maps_key
  end

  test "default label is Default" do
    api_key = ApiKey.new(user: users(:one), workspace: workspaces(:one), google_maps_key: "AIzaSyTest")
    assert_equal "Default", api_key.label
  end

  test "valid with all required attributes" do
    api_key = ApiKey.new(user: users(:one), workspace: workspaces(:one), google_maps_key: "AIzaSyTest123")
    assert api_key.valid?
  end
end
