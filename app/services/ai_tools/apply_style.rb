module AiTools
  class ApplyStyle < ::RubyLLM::Tool
    description "Apply a map style by name. Available styles: Default, Silver, Night, Retro, Aubergine, Minimal."
    def name = "apply_style"

    param :map_id, desc: "ID of the current map", required: true
    param :style_name, desc: "Name of the style to apply", required: true

    def execute(map_id:, style_name:)
      map = Map.find(map_id)

      if style_name.downcase == "default"
        map.update!(style_json: nil, google_map_id: nil)
        return { success: true, style: "Default" }
      end

      style = MapStyle.system_presets.find_by("LOWER(name) = ?", style_name.downcase)
      return { success: false, error: "Style '#{style_name}' not found. Available: Default, Silver, Night, Retro, Aubergine, Minimal." } unless style

      map.update!(style_json: style.style_json, google_map_id: nil)
      { success: true, style: style.name }
    end
  end
end
