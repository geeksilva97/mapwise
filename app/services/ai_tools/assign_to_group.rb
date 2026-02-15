module AiTools
  class AssignToGroup < Base
    def self.definition
      {
        name: "assign_to_group",
        description: "Assign markers to a group by group name. Creates the group if it doesn't exist.",
        input_schema: {
          type: "object",
          properties: {
            marker_ids: {
              type: "array",
              items: { type: "integer" },
              description: "Array of marker IDs to assign"
            },
            group_name: { type: "string", description: "Name of the group to assign markers to" }
          },
          required: ["marker_ids", "group_name"]
        }
      }
    end

    def self.execute(map, params)
      group = map.marker_groups.find_by(name: params["group_name"])
      group ||= map.marker_groups.create!(name: params["group_name"])

      markers = map.markers.where(id: params["marker_ids"])
      markers.update_all(marker_group_id: group.id, color: group.color)

      { success: true, group_id: group.id, assigned_count: markers.count }
    end
  end
end
