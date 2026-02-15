require "test_helper"

class ChatMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @map = maps(:one)
    sign_in_as(@user)
  end

  test "create saves user message and enqueues job" do
    assert_difference("ChatMessage.count") do
      post map_chat_messages_path(@map),
           params: { chat_message: { content: "Add 3 restaurants" } },
           as: :json
    end

    assert_response :ok

    message = ChatMessage.last
    assert_equal "user", message.role
    assert_equal "Add 3 restaurants", message.content
    assert_equal @map, message.map

    assert_enqueued_with(job: AiChatJob, args: [@map.id, message.id])
  end

  test "create with blank content returns error" do
    assert_no_difference("ChatMessage.count") do
      post map_chat_messages_path(@map),
           params: { chat_message: { content: "" } },
           as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create strips whitespace from content" do
    post map_chat_messages_path(@map),
         params: { chat_message: { content: "  Add a marker  " } },
         as: :json

    assert_response :ok
    assert_equal "Add a marker", ChatMessage.last.content
  end

  test "create requires authentication" do
    sign_out
    post map_chat_messages_path(@map),
         params: { chat_message: { content: "Hello" } },
         as: :json

    assert_redirected_to new_session_path
  end

  test "create on other user's map returns not found" do
    other_map = maps(:two)
    post map_chat_messages_path(other_map),
         params: { chat_message: { content: "Hello" } },
         as: :json

    assert_response :not_found
  end

  test "clear destroys all chat messages and redirects" do
    @map.chat_messages.create!(role: "user", content: "Hello")
    @map.chat_messages.create!(role: "assistant", content: "Hi!")

    count = @map.chat_messages.count
    assert count >= 2

    assert_difference("ChatMessage.count", -count) do
      delete clear_map_chat_messages_path(@map)
    end

    assert_equal 0, @map.chat_messages.reload.count
    assert_redirected_to edit_map_path(@map, tab: "ai")
  end

  test "clear requires authentication" do
    sign_out
    delete clear_map_chat_messages_path(@map)
    assert_redirected_to new_session_path
  end

  test "clear on other user's map returns not found" do
    other_map = maps(:two)
    delete clear_map_chat_messages_path(other_map)
    assert_response :not_found
  end
end
