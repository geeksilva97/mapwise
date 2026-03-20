class ApiKeys::List
  def self.call(workspace)
    workspace.api_keys
  end
end
