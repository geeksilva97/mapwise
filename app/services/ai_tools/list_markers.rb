module AiTools
  class ListMarkers < Base
    def self.definition
      {
        name: "list_markers",
        description: "Get all markers currently on the map.",
        input_schema: {
          type: "object",
          properties: {}
        }
      }
    end

    def self.execute(map, _params)
      markers = map.markers.order(:position).map do |m|
        {
          id: m.id,
          title: m.title,
          lat: m.lat,
          lng: m.lng,
          color: m.color,
          group: m.marker_group&.name
        }
      end
      { success: true, markers: markers, count: markers.size }
    end
  end
end
