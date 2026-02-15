module AiTools
  class UpdateMarker < Base
    def self.definition
      {
        name: "update_marker",
        description: "Update an existing marker's properties.",
        input_schema: {
          type: "object",
          properties: {
            marker_id: { type: "integer", description: "ID of the marker to update" },
            title: { type: "string", description: "New title" },
            description: { type: "string", description: "New description" },
            color: { type: "string", description: "New hex color code" },
            lat: { type: "number", description: "New latitude" },
            lng: { type: "number", description: "New longitude" }
          },
          required: ["marker_id"]
        }
      }
    end

    def self.execute(map, params)
      marker = map.markers.find(params["marker_id"])
      updates = params.slice("title", "description", "color", "lat", "lng").compact
      marker.update!(updates)
      { success: true, marker_id: marker.id }
    end
  end
end
