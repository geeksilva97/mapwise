module AiTools
  class CreateGroup < Base
    def self.definition
      {
        name: "create_group",
        description: "Create a new marker group for organizing markers.",
        input_schema: {
          type: "object",
          properties: {
            name: { type: "string", description: "Group name" },
            color: { type: "string", description: "Hex color code for the group" }
          },
          required: ["name"]
        }
      }
    end

    def self.execute(map, params)
      group = map.marker_groups.create!(
        name: params["name"],
        color: params["color"].presence || "#6B7280"
      )
      { success: true, group_id: group.id, name: group.name }
    end
  end
end
