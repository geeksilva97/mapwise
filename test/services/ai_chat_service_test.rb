require "test_helper"
require "webmock/minitest"

class AiChatServiceTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
    @service = AiChatService.new(@map)
  end

  test "returns text response for simple question" do
    stub_anthropic_response(stop_reason: "end_turn", content: [
      { "type" => "text", "text" => "There are 2 markers on this map." }
    ])

    result = @service.call("How many markers are on this map?")
    assert_equal "There are 2 markers on this map.", result
  end

  test "executes tool and returns final response" do
    # First call returns tool_use
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        { status: 200, body: {
          id: "msg_1",
          type: "message",
          role: "assistant",
          stop_reason: "tool_use",
          content: [
            { "type" => "tool_use", "id" => "toolu_1", "name" => "create_marker",
              "input" => { "lat" => 40.7580, "lng" => -73.9855, "title" => "Times Square" } }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" } },
        { status: 200, body: {
          id: "msg_2",
          type: "message",
          role: "assistant",
          stop_reason: "end_turn",
          content: [
            { "type" => "text", "text" => "I've added a marker at Times Square." }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" } }
      )

    result = @service.call("Add a marker at Times Square")
    assert_equal "I've added a marker at Times Square.", result

    marker = @map.markers.find_by(title: "Times Square")
    assert marker
    assert_in_delta 40.7580, marker.lat
  end

  test "handles tool execution errors gracefully" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        { status: 200, body: {
          id: "msg_1",
          type: "message",
          role: "assistant",
          stop_reason: "tool_use",
          content: [
            { "type" => "tool_use", "id" => "toolu_1", "name" => "delete_marker",
              "input" => { "marker_id" => 999999 } }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" } },
        { status: 200, body: {
          id: "msg_2",
          type: "message",
          role: "assistant",
          stop_reason: "end_turn",
          content: [
            { "type" => "text", "text" => "That marker was not found." }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" } }
      )

    result = @service.call("Delete marker 999999")
    assert_equal "That marker was not found.", result
  end

  test "respects max rounds limit" do
    # Stub to always return tool_use (would loop forever without limit)
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: {
        id: "msg_loop",
        type: "message",
        role: "assistant",
        stop_reason: "tool_use",
        content: [
          { "type" => "text", "text" => "Still working..." },
          { "type" => "tool_use", "id" => "toolu_loop", "name" => "list_markers", "input" => {} }
        ]
      }.to_json, headers: { "Content-Type" => "application/json" })

    result = @service.call("Keep listing markers")
    assert_equal "Still working...", result
  end

  test "system prompt includes map context" do
    # We test this indirectly by checking the request body
    request_body = nil
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with { |req| request_body = JSON.parse(req.body); true }
      .to_return(status: 200, body: {
        id: "msg_1",
        type: "message",
        role: "assistant",
        stop_reason: "end_turn",
        content: [{ "type" => "text", "text" => "Hello!" }]
      }.to_json, headers: { "Content-Type" => "application/json" })

    @service.call("Hello")

    assert_includes request_body["system"], "My First Map"
    assert request_body["tools"].is_a?(Array)
    assert request_body["tools"].any? { |t| t["name"] == "create_marker" }
  end

  private

  def stub_anthropic_response(stop_reason:, content:)
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: {
        id: "msg_test",
        type: "message",
        role: "assistant",
        stop_reason: stop_reason,
        content: content
      }.to_json, headers: { "Content-Type" => "application/json" })
  end
end
