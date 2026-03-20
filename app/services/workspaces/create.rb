class Workspaces::Create
  def self.call(user, params)
    workspace = ::Workspace.new(params)
    if workspace.save
      ::Membership.create!(user: user, workspace: workspace, role: "admin")
    end
    workspace
  end
end
