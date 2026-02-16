module AiTools
  class AssignToGroup < RubyLLM::Tool
    description "Assign markers to a group by group name. Creates the group if it doesn't exist."
    def name = "assign_to_group"

    params do
      integer :map_id, description: "ID of the current map"
      array :marker_ids, of: :integer, description: "Array of marker IDs to assign"
      string :group_name, description: "Name of the group to assign markers to"
    end

    def execute(map_id:, marker_ids:, group_name:)
      map = Map.find(map_id)
      group = map.marker_groups.find_by(name: group_name)
      group ||= map.marker_groups.create!(name: group_name)

      markers = map.markers.where(id: marker_ids)
      markers.update_all(marker_group_id: group.id, color: group.color)

      { success: true, group_id: group.id, assigned_count: markers.count }
    end
  end
end
