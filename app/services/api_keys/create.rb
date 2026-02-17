class ApiKeys::Create
  def self.call(user, params)
    api_key = user.api_keys.build(params)
    api_key.save
    api_key
  end
end
