class Workspaces::Update
  def self.call(workspace, params)
    workspace.update(params)
  end
end
