class BackfillPersonalWorkspaces < ActiveRecord::Migration[8.1]
  def up
    User.find_each do |user|
      workspace = Workspace.create!(name: "#{user.name}'s Workspace", personal: true)
      Membership.create!(user: user, workspace: workspace, role: "admin")

      Map.where(user_id: user.id).update_all(workspace_id: workspace.id)
      ApiKey.where(user_id: user.id).update_all(workspace_id: workspace.id)
      MapStyle.where(user_id: user.id).update_all(workspace_id: workspace.id)
    end

    change_column_null :maps, :workspace_id, false
    change_column_null :api_keys, :workspace_id, false
  end

  def down
    change_column_null :api_keys, :workspace_id, true
    change_column_null :maps, :workspace_id, true

    Membership.delete_all
    Workspace.delete_all

    Map.update_all(workspace_id: nil)
    ApiKey.update_all(workspace_id: nil)
    MapStyle.update_all(workspace_id: nil)
  end
end
