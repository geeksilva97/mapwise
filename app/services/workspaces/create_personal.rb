class Workspaces::CreatePersonal
  def self.call(user)
    workspace = ::Workspace.create!(name: "#{user.name}'s Workspace", personal: true)
    ::Membership.create!(user: user, workspace: workspace, role: "admin")
    workspace
  end
end
