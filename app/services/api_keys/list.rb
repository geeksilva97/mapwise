class ApiKeys::List
  def self.call(user)
    user.api_keys
  end
end
