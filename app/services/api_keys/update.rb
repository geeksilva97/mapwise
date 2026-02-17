class ApiKeys::Update
  def self.call(api_key, params)
    api_key.update(params)
  end
end
