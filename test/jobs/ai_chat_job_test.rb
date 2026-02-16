require "test_helper"

class AiChatJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionCable::TestHelper

  setup do
    @map = maps(:one)
    @message = @map.chat_messages.create!(role: "user", content: "Add a marker in NYC")
  end

  test "creates assistant message" do
    mock_service_call("I've added a marker in NYC.") do
      assert_difference("ChatMessage.count") do
        AiChatJob.perform_now(@map.id, @message.id)
      end
    end

    assistant = ChatMessage.last
    assert_equal "assistant", assistant.role
    assert_equal "I've added a marker in NYC.", assistant.content
  end

  test "broadcasts to correct channel" do
    mock_service_call("Done!") do
      assert_broadcasts("ai_chat_map_#{@map.id}", 1) do
        AiChatJob.perform_now(@map.id, @message.id)
      end
    end
  end

  test "handles errors gracefully" do
    mock_service_call_raises("API down") do
      assert_difference("ChatMessage.count") do
        AiChatJob.perform_now(@map.id, @message.id)
      end
    end

    error_message = ChatMessage.last
    assert_equal "assistant", error_message.role
    assert_includes error_message.content, "Sorry, something went wrong"
  end

  private

  def mock_service_call(response_text, &block)
    original_new = AiChatService.method(:new)
    AiChatService.define_singleton_method(:new) do |*args|
      service = original_new.call(*args)
      service.define_singleton_method(:call) { |_| response_text }
      service
    end

    block.call
  ensure
    AiChatService.define_singleton_method(:new, original_new)
  end

  def mock_service_call_raises(error_message, &block)
    original_new = AiChatService.method(:new)
    AiChatService.define_singleton_method(:new) do |*args|
      service = original_new.call(*args)
      service.define_singleton_method(:call) { |_| raise StandardError, error_message }
      service
    end

    block.call
  ensure
    AiChatService.define_singleton_method(:new, original_new)
  end
end
