module AiTools
  class CreateGroup < RubyLLM::Tool
    description "Create a new marker group for organizing markers."
    def name = "create_group"

    param :map_id, desc: "ID of the current map", required: true
    param :name, desc: "Group name", required: true
    param :color, desc: "Hex color code for the group", required: false

    def execute(map_id:, name:, color: nil)
      map = Map.find(map_id)
      group = map.marker_groups.create!(
        name: name,
        color: color.presence || "#6B7280"
      )
      { success: true, group_id: group.id, name: group.name }
    end
  end
end
