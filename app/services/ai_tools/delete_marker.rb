module AiTools
  class DeleteMarker < Base
    def self.definition
      {
        name: "delete_marker",
        description: "Remove a marker from the map.",
        input_schema: {
          type: "object",
          properties: {
            marker_id: { type: "integer", description: "ID of the marker to delete" }
          },
          required: ["marker_id"]
        }
      }
    end

    def self.execute(map, params)
      marker = map.markers.find(params["marker_id"])
      marker.destroy!
      { success: true, marker_id: marker.id }
    end
  end
end
