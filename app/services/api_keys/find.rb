class ApiKeys::Find
  def self.call(user, id)
    user.api_keys.find(id)
  end
end
