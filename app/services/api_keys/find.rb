class ApiKeys::Find
  def self.call(workspace, id)
    workspace.api_keys.find(id)
  end
end
