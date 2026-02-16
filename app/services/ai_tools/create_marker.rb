module AiTools
  class CreateMarker < ::RubyLLM::Tool
    description "Add a new marker to the map at the specified coordinates."
    def name = "create_marker"

    param :map_id, desc: "ID of the current map", required: true
    param :lat, type: :number, desc: "Latitude (-90 to 90)", required: true
    param :lng, type: :number, desc: "Longitude (-180 to 180)", required: true
    param :title, desc: "Marker title", required: false
    param :description, desc: "Marker description", required: false
    param :color, desc: "Hex color code (e.g. #FF0000)", required: false

    def execute(map_id:, lat:, lng:, title: nil, description: nil, color: nil)
      map = Map.find(map_id)
      marker = map.markers.create!(
        lat: lat,
        lng: lng,
        title: title,
        description: description,
        color: color.presence || "#FF0000"
      )
      { success: true, marker_id: marker.id, title: marker.title }
    end
  end
end
