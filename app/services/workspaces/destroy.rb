class Workspaces::Destroy
  def self.call(workspace)
    workspace.destroy
  end
end
