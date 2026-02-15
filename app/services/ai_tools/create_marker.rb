module AiTools
  class CreateMarker < Base
    def self.definition
      {
        name: "create_marker",
        description: "Add a new marker to the map at the specified coordinates.",
        input_schema: {
          type: "object",
          properties: {
            lat: { type: "number", description: "Latitude (-90 to 90)" },
            lng: { type: "number", description: "Longitude (-180 to 180)" },
            title: { type: "string", description: "Marker title" },
            description: { type: "string", description: "Marker description" },
            color: { type: "string", description: "Hex color code (e.g. #FF0000)" }
          },
          required: ["lat", "lng"]
        }
      }
    end

    def self.execute(map, params)
      marker = map.markers.create!(
        lat: params["lat"],
        lng: params["lng"],
        title: params["title"],
        description: params["description"],
        color: params["color"].presence || "#FF0000"
      )
      { success: true, marker_id: marker.id, title: marker.title }
    end
  end
end
