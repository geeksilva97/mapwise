module AiTools
  class UpdateMarker < ::RubyLLM::Tool
    description "Update an existing marker's properties."
    def name = "update_marker"

    param :map_id, desc: "ID of the current map", required: true
    param :marker_id, type: :integer, desc: "ID of the marker to update", required: true
    param :title, desc: "New title", required: false
    param :description, desc: "New description", required: false
    param :color, desc: "New hex color code", required: false
    param :lat, type: :number, desc: "New latitude", required: false
    param :lng, type: :number, desc: "New longitude", required: false

    def execute(map_id:, marker_id:, title: nil, description: nil, color: nil, lat: nil, lng: nil)
      map = Map.find(map_id)
      marker = map.markers.find(marker_id)
      updates = { title: title, description: description, color: color, lat: lat, lng: lng }.compact
      marker.update!(updates)
      { success: true, marker_id: marker.id }
    end
  end
end
