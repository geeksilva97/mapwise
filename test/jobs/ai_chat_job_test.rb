require "test_helper"
require "webmock/minitest"

class AiChatJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionCable::TestHelper

  setup do
    @map = maps(:one)
    @message = @map.chat_messages.create!(role: "user", content: "Add a marker in NYC")
  end

  test "creates assistant message" do
    stub_anthropic_simple_response("I've added a marker in NYC.")

    assert_difference("ChatMessage.count") do
      AiChatJob.perform_now(@map.id, @message.id)
    end

    assistant = ChatMessage.last
    assert_equal "assistant", assistant.role
    assert_equal "I've added a marker in NYC.", assistant.content
  end

  test "broadcasts to correct channel" do
    stub_anthropic_simple_response("Done!")

    assert_broadcasts("ai_chat_map_#{@map.id}", 1) do
      AiChatJob.perform_now(@map.id, @message.id)
    end
  end

  test "handles API errors gracefully" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_raise(StandardError.new("API down"))

    assert_difference("ChatMessage.count") do
      AiChatJob.perform_now(@map.id, @message.id)
    end

    error_message = ChatMessage.last
    assert_equal "assistant", error_message.role
    assert_includes error_message.content, "Sorry, something went wrong"
  end

  private

  def stub_anthropic_simple_response(text)
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: {
        id: "msg_test",
        type: "message",
        role: "assistant",
        stop_reason: "end_turn",
        content: [{ "type" => "text", "text" => text }]
      }.to_json, headers: { "Content-Type" => "application/json" })
  end
end
