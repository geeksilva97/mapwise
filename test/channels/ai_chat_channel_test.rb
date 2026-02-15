require "test_helper"

class AiChatChannelTest < ActionCable::Channel::TestCase
  setup do
    @user = users(:one)
    @map = maps(:one)
    stub_connection(current_user: @user)
  end

  test "subscribes to own map" do
    subscribe(map_id: @map.id)

    assert subscription.confirmed?
    assert_has_stream "ai_chat_map_#{@map.id}"
  end

  test "rejects subscription to other user's map" do
    other_map = maps(:two)
    subscribe(map_id: other_map.id)

    assert subscription.rejected?
  end

  test "rejects subscription with invalid map_id" do
    subscribe(map_id: 999999)

    assert subscription.rejected?
  end
end
