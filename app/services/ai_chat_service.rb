class AiChatService
  MAX_ROUNDS = 10

  TOOLS = [
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
    @client = Anthropic::Client.new(api_key: Rails.application.credentials.anthropic_api_key)
  end

  def call(user_message)
    messages = build_messages(user_message)
    rounds = 0

    loop do
      response = @client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 4096,
        system: system_prompt,
        tools: tool_definitions,
        messages: messages
      )

      if response.stop_reason.to_s == "tool_use"
        @mutated = false
        snapshot = map_snapshot
        tool_results = execute_tools(response.content)
        broadcast_round_update(snapshot) if @mutated
        messages << { role: "assistant", content: serialize_content(response.content) }
        messages << { role: "user", content: tool_results }
        rounds += 1
        break extract_text(response.content) if rounds >= MAX_ROUNDS
      else
        break extract_text(response.content)
      end
    end
  end

  private

  def system_prompt
    markers_info = @map.markers.includes(:marker_group).order(:position).map do |m|
      parts = ["ID:#{m.id}", m.title.presence || "Untitled", "(#{m.lat}, #{m.lng})", "color:#{m.color}"]
      parts << "group:#{m.marker_group.name}" if m.marker_group
      parts.join(" | ")
    end

    groups_info = @map.marker_groups.ordered.map do |g|
      "ID:#{g.id} | #{g.name} | color:#{g.color} | #{g.markers.count} markers"
    end

    <<~PROMPT
      You are a helpful map assistant for MapWise. You help users create and modify maps by using the available tools.

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
      - If the user asks something that doesn't require tools (like a question), just answer directly.
    PROMPT
  end

  def build_messages(user_message)
    recent = @map.chat_messages.ordered.last(20)
    messages = recent.map do |msg|
      { role: msg.role, content: msg.content }
    end
    messages << { role: "user", content: user_message }
    messages
  end

  def tool_definitions
    TOOLS.map(&:definition)
  end

  def execute_tools(content_blocks)
    content_blocks.filter_map do |block|
      next unless block_type(block) == "tool_use"

      tool_name = block_value(block, :name)
      tool_class = TOOLS.find { |t| t.tool_name == tool_name }
      @mutated = true unless READ_ONLY_TOOLS.include?(tool_name)
      input = block_value(block, :input)
      input = input.is_a?(Hash) ? stringify_keys(input) : input

      result = if tool_class
        begin
          tool_class.execute(@map, input)
        rescue => e
          { error: e.message }
        end
      else
        { error: "Unknown tool: #{tool_name}" }
      end

      {
        type: "tool_result",
        tool_use_id: block_value(block, :id),
        content: result.to_json
      }
    end
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

  def extract_text(content_blocks)
    content_blocks.filter_map do |block|
      block_value(block, :text) if block_type(block) == "text"
    end.join("\n").presence || "Done!"
  end

  def serialize_content(content_blocks)
    content_blocks.map do |block|
      block.respond_to?(:to_h) ? block.to_h : block
    end
  end

  # Unified accessor: works with both objects (gem response) and hashes (test stubs)
  def block_type(block)
    val = block.respond_to?(:type) ? block.type : block["type"]
    val.to_s
  end

  def block_value(block, key)
    if block.respond_to?(key)
      block.send(key)
    else
      block[key.to_s] || block[key]
    end
  end

  def stringify_keys(hash)
    hash.transform_keys(&:to_s)
  end
end
