module AiTools
  class ApplyStyle < Base
    def self.definition
      {
        name: "apply_style",
        description: "Apply a map style by name. Available styles: Default, Silver, Night, Retro, Aubergine, Minimal.",
        input_schema: {
          type: "object",
          properties: {
            style_name: { type: "string", description: "Name of the style to apply" }
          },
          required: ["style_name"]
        }
      }
    end

    def self.execute(map, params)
      style_name = params["style_name"]

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
