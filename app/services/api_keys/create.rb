class ApiKeys::Create
  def self.call(workspace, user, params)
    api_key = workspace.api_keys.build(params)
    api_key.user = user
    api_key.save
    api_key
  end
end
