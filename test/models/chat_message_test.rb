require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    message = ChatMessage.new(map: maps(:one), role: "user", content: "Hello")
    assert message.valid?
  end

  test "belongs to map" do
    message = chat_messages(:user_message)
    assert_equal maps(:one), message.map
  end

  test "validates presence of role" do
    message = ChatMessage.new(map: maps(:one), content: "Hello")
    assert_not message.valid?
    assert_includes message.errors[:role], "can't be blank"
  end

  test "validates role inclusion" do
    message = ChatMessage.new(map: maps(:one), role: "system", content: "Hello")
    assert_not message.valid?
    assert_includes message.errors[:role], "is not included in the list"
  end

  test "validates presence of content" do
    message = ChatMessage.new(map: maps(:one), role: "user")
    assert_not message.valid?
    assert_includes message.errors[:content], "can't be blank"
  end

  test "allows user role" do
    message = ChatMessage.new(map: maps(:one), role: "user", content: "Hello")
    assert message.valid?
  end

  test "allows assistant role" do
    message = ChatMessage.new(map: maps(:one), role: "assistant", content: "Hello")
    assert message.valid?
  end

  test "ordered scope sorts by created_at" do
    messages = maps(:one).chat_messages.ordered
    assert_equal chat_messages(:user_message), messages.first
    assert_equal chat_messages(:assistant_message), messages.last
  end

  test "tool_calls can store JSON" do
    message = ChatMessage.create!(
      map: maps(:one),
      role: "assistant",
      content: "Done",
      tool_calls: [{ "name" => "create_marker", "input" => { "lat" => 40.7 } }]
    )
    message.reload
    assert_equal "create_marker", message.tool_calls.first["name"]
  end

  test "destroyed when map is destroyed" do
    map = maps(:one)
    assert map.chat_messages.count > 0
    map.destroy
    assert_equal 0, ChatMessage.where(map_id: map.id).count
  end
end
