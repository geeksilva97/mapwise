class AiChatJob < ApplicationJob
  queue_as :default

  def perform(map_id, message_id)
    map = Map.find(map_id)
    message = map.chat_messages.find(message_id)

    snapshot = { center_lat: map.center_lat, center_lng: map.center_lng, zoom: map.zoom, style_json: map.style_json }

    service = AiChatService.new(map)
    result = service.call(message.content)

    assistant_message = map.chat_messages.create!(
      role: "assistant",
      content: result
    )

    broadcast_response(map, assistant_message, snapshot)
  rescue => e
    Rails.logger.error("AiChatJob failed: #{e.message}")
    error_message = map.chat_messages.create!(
      role: "assistant",
      content: "Sorry, something went wrong. Please try again."
    )
    broadcast_response(map, error_message, snapshot || {})
  end

  private

  def broadcast_response(map, assistant_message, prev)
    map.reload

    payload = {
      type: "assistant_message",
      html: render_message_html(assistant_message),
      markers_json: map.markers.select(:id, :lat, :lng, :title, :description, :color, :marker_group_id).to_json,
      markers_html: render_markers_list_html(map),
      marker_count: map.markers.count,
      groups_json: map.marker_groups.ordered.to_json(only: [ :id, :name, :color, :visible ])
    }

    if map.style_json != prev[:style_json]
      payload[:style_json] = map.style_json
    end

    if map.center_lat != prev[:center_lat] || map.center_lng != prev[:center_lng] || map.zoom != prev[:zoom]
      payload[:center_lat] = map.center_lat
      payload[:center_lng] = map.center_lng
      payload[:zoom] = map.zoom
    end

    ActionCable.server.broadcast("ai_chat_map_#{map.id}", payload)
  end

  def render_message_html(message)
    ApplicationController.render(
      partial: "chat_messages/chat_message",
      locals: { message: message }
    )
  end

  def render_markers_list_html(map)
    ApplicationController.render(
      partial: "markers/marker_item",
      collection: map.markers.where(marker_group_id: nil).order(:position),
      as: :marker
    )
  end
end
