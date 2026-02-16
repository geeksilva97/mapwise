module AiTools
  class DeleteMarker < ::RubyLLM::Tool
    description "Remove a marker from the map."
    def name = "delete_marker"

    param :map_id, desc: "ID of the current map", required: true
    param :marker_id, type: :integer, desc: "ID of the marker to delete", required: true

    def execute(map_id:, marker_id:)
      map = Map.find(map_id)
      marker = map.markers.find(marker_id)
      marker.destroy!
      { success: true, marker_id: marker.id }
    end
  end
end
