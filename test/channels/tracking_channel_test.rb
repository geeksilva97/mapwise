require "test_helper"

class TrackingChannelTest < ActionCable::Channel::TestCase
  setup do
    @user = users(:one)
    @map = maps(:one)
  end

  test "subscribes to own map" do
    stub_connection current_user: @user
    subscribe(map_id: @map.id)

    assert subscription.confirmed?
    assert_has_stream "tracking_map_#{@map.id}"
  end

  test "rejects subscription to other user map" do
    other_user = users(:two)
    stub_connection current_user: other_user
    subscribe(map_id: @map.id)

    assert subscription.rejected?
  end

  test "rejects subscription to non-existent map" do
    stub_connection current_user: @user
    subscribe(map_id: -1)

    assert subscription.rejected?
  end
end
