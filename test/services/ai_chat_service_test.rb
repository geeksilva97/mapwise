require "test_helper"

class AiChatServiceTest < ActiveSupport::TestCase
  setup do
    @map = maps(:one)
  end

  test "returns text response for simple question" do
    service = build_service_with_mock_chat("There are 2 markers on this map.")
    result = service.call("How many markers are on this map?")
    assert_equal "There are 2 markers on this map.", result
  end

  test "executes tool and returns final response" do
    tool_call = RubyLLM::ToolCall.new(
      id: "toolu_1",
      name: "create_marker",
      arguments: { "map_id" => @map.id, "lat" => 40.7580, "lng" => -73.9855, "title" => "Times Square" }
    )

    service = build_service_with_tool_mock(tool_call, "I've added a marker at Times Square.")
    result = service.call("Add a marker at Times Square")
    assert_equal "I've added a marker at Times Square.", result

    marker = @map.markers.find_by(title: "Times Square")
    assert marker
    assert_in_delta 40.7580, marker.lat
  end

  test "handles tool execution errors gracefully" do
    tool_call = RubyLLM::ToolCall.new(
      id: "toolu_1",
      name: "delete_marker",
      arguments: { "map_id" => @map.id, "marker_id" => 999999 }
    )

    service = build_service_with_tool_mock(tool_call, "That marker was not found.")
    result = service.call("Delete marker 999999")
    assert_equal "That marker was not found.", result
  end

  test "system prompt includes map context and map ID" do
    service = AiChatService.new(@map)
    prompt = service.send(:system_prompt)

    assert_includes prompt, "My First Map"
    assert_includes prompt, "Current map ID: #{@map.id}"
    assert_includes prompt, "Always pass this map_id when using tools."
  end

  private

  def build_service_with_mock_chat(response_text, &customize)
    mock_chat = build_mock_chat(response_text)
    customize&.call(mock_chat)

    service = AiChatService.new(@map)
    service.define_singleton_method(:build_chat) { mock_chat }
    service
  end

  def build_service_with_tool_mock(tool_call, final_response_text)
    mock_chat = build_mock_chat_with_tool(tool_call, final_response_text)

    service = AiChatService.new(@map)
    service.define_singleton_method(:build_chat) { mock_chat }
    service
  end

  def build_mock_chat(response_text)
    response = Struct.new(:content).new(response_text)

    mock = Object.new
    mock.define_singleton_method(:with_instructions) { |_| self }
    mock.define_singleton_method(:with_tools) { |*_| self }
    mock.define_singleton_method(:on_tool_call) { |&_| self }
    mock.define_singleton_method(:on_tool_result) { |&_| self }
    mock.define_singleton_method(:add_message) { |**_| nil }
    mock.define_singleton_method(:ask) { |_| response }
    mock
  end

  def build_mock_chat_with_tool(tool_call, final_response_text)
    response = Struct.new(:content).new(final_response_text)

    tool_classes = AiChatService::TOOL_CLASSES
    tool_class = tool_classes.find { |t| t.new.name == tool_call.name }
    on_tool_call_block = nil
    on_tool_result_block = nil

    mock = Object.new
    mock.define_singleton_method(:with_instructions) { |_| self }
    mock.define_singleton_method(:with_tools) { |*_| self }
    mock.define_singleton_method(:on_tool_call) { |&blk| on_tool_call_block = blk; self }
    mock.define_singleton_method(:on_tool_result) { |&blk| on_tool_result_block = blk; self }
    mock.define_singleton_method(:add_message) { |**_| nil }
    mock.define_singleton_method(:ask) do |_|
      on_tool_call_block&.call(tool_call)

      kwargs = tool_call.arguments.transform_keys(&:to_sym)
      begin
        result = tool_class.new.execute(**kwargs)
      rescue => e
        result = { error: e.message }
      end

      on_tool_result_block&.call(result)
      response
    end
    mock
  end
end
