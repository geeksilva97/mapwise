class ApiKeys::Destroy
  def self.call(api_key)
    api_key.destroy
  end
end
