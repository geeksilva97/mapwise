module AiTools
  class UpdateMap < ::RubyLLM::Tool
    description "Change map settings like title, description, center position, or zoom level."
    def name = "update_map"

    param :map_id, desc: "ID of the current map", required: true
    param :title, desc: "New map title", required: false
    param :description, desc: "New map description", required: false
    param :center_lat, type: :number, desc: "New center latitude", required: false
    param :center_lng, type: :number, desc: "New center longitude", required: false
    param :zoom, type: :integer, desc: "New zoom level (1-20)", required: false

    def execute(map_id:, title: nil, description: nil, center_lat: nil, center_lng: nil, zoom: nil)
      map = Map.find(map_id)
      updates = { title: title, description: description, center_lat: center_lat, center_lng: center_lng, zoom: zoom }.compact
      map.update!(updates)
      { success: true }
    end
  end
end
