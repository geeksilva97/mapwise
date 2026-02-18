class AiChatService
  MAX_TOOL_CALLS = 30

  TOOL_CLASSES = [
    AiTools::CreateMarker,
    AiTools::UpdateMarker,
    AiTools::DeleteMarker,
    AiTools::ListMarkers,
    AiTools::UpdateMap,
    AiTools::ApplyStyle,
    AiTools::CreateGroup,
    AiTools::AssignToGroup
  ].freeze

  READ_ONLY_TOOLS = %w[list_markers].freeze

  def initialize(map)
    @map = map
  end

  def call(user_message)
    @snapshot = map_snapshot
    @last_tool_mutating = false
    @tool_call_count = 0

    chat = build_chat

    @map.chat_messages.ordered.last(20).each do |msg|
      chat.add_message(role: msg.role.to_sym, content: msg.content)
    end

    response = chat.ask(user_message)
    response.content.presence || "Done!"
  end

  private

  def build_chat
    RubyLLM.chat(model: model_id)
      .with_instructions(system_prompt)
      .with_tools(*TOOL_CLASSES)
      .on_tool_call { |tc| handle_tool_call(tc) }
      .on_tool_result { |_result| handle_tool_result }
  end

  def model_id
    ENV.fetch("RUBY_LLM_MODEL", "claude-sonnet-4-5-20250929")
  end

  def handle_tool_call(tool_call)
    @tool_call_count += 1
    raise ToolCallLimitExceededError.new("Tool call limit exceeded (#{MAX_TOOL_CALLS})", context: { map_id: @map.id }) if @tool_call_count > MAX_TOOL_CALLS
    @last_tool_mutating = !READ_ONLY_TOOLS.include?(tool_call.name)
  end

  def handle_tool_result
    return unless @last_tool_mutating

    @map.reload
    broadcast_round_update(@snapshot)
    @snapshot = map_snapshot
    @last_tool_mutating = false
  end

  def system_prompt
    markers_info = @map.markers.includes(:marker_group).order(:position).map do |m|
      parts = [ "ID:#{m.id}", m.title.presence || "Untitled", "(#{m.lat}, #{m.lng})", "color:#{m.color}" ]
      parts << "group:#{m.marker_group.name}" if m.marker_group
      parts.join(" | ")
    end

    groups_info = @map.marker_groups.ordered.map do |g|
      "ID:#{g.id} | #{g.name} | color:#{g.color} | #{g.markers.count} markers"
    end

    <<~PROMPT
      You are a map assistant for MapWise. Your ONLY purpose is to help users create and modify their map using the available tools.

      IMPORTANT: You MUST refuse any request or question that is not about this map, its markers, groups, styles, or geographic/mapping topics. This includes but is not limited to: general knowledge, trivia, coding, math, writing, translation, or any other non-map topic. When refusing, respond with: "I can only help with your map. What would you like to add or change?"

      Current map ID: #{@map.id}
      Always pass this map_id when using tools.

      Current map: "#{@map.title}"
      #{@map.description.present? ? "Description: #{@map.description}" : ""}
      Center: (#{@map.center_lat}, #{@map.center_lng}) | Zoom: #{@map.zoom}

      Current markers (#{@map.markers.count}):
      #{markers_info.any? ? markers_info.join("\n") : "None"}

      Current groups (#{@map.marker_groups.count}):
      #{groups_info.any? ? groups_info.join("\n") : "None"}

      Available map styles: Default, Silver, Night, Retro, Aubergine, Minimal

      Instructions:
      - Use tools to make changes to the map. Don't just describe what you would do — actually do it.
      - When creating markers for real-world locations, use accurate coordinates.
      - After making changes, briefly confirm what you did.
      - Be concise in your responses.
    PROMPT
  end

  def map_snapshot
    { center_lat: @map.center_lat, center_lng: @map.center_lng, zoom: @map.zoom, style_json: @map.style_json }
  end

  def broadcast_round_update(prev)
    @map.reload

    payload = {
      type: "tool_update",
      markers_json: @map.markers.select(:id, :lat, :lng, :title, :description, :color, :marker_group_id).to_json,
      markers_html: ApplicationController.render(
        partial: "markers/marker_item",
        collection: @map.markers.where(marker_group_id: nil).order(:position),
        as: :marker
      ),
      marker_count: @map.markers.count,
      groups_json: @map.marker_groups.ordered.to_json(only: [ :id, :name, :color, :visible ])
    }

    if @map.style_json != prev[:style_json]
      payload[:style_json] = @map.style_json
    end

    if @map.center_lat != prev[:center_lat] || @map.center_lng != prev[:center_lng] || @map.zoom != prev[:zoom]
      payload[:center_lat] = @map.center_lat
      payload[:center_lng] = @map.center_lng
      payload[:zoom] = @map.zoom
    end

    ActionCable.server.broadcast("ai_chat_map_#{@map.id}", payload)
  end
end
