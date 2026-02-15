module AiTools
  class UpdateMap < Base
    def self.definition
      {
        name: "update_map",
        description: "Change map settings like title, description, center position, or zoom level.",
        input_schema: {
          type: "object",
          properties: {
            title: { type: "string", description: "New map title" },
            description: { type: "string", description: "New map description" },
            center_lat: { type: "number", description: "New center latitude" },
            center_lng: { type: "number", description: "New center longitude" },
            zoom: { type: "integer", description: "New zoom level (1-20)" }
          }
        }
      }
    end

    def self.execute(map, params)
      updates = params.slice("title", "description", "center_lat", "center_lng", "zoom").compact
      map.update!(updates)
      { success: true }
    end
  end
end
