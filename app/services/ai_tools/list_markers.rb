module AiTools
  class ListMarkers < RubyLLM::Tool
    description "Get all markers currently on the map."
    def name = "list_markers"

    param :map_id, desc: "ID of the current map", required: true

    def execute(map_id:)
      map = Map.find(map_id)
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
