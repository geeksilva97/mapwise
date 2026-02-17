class Maps::Find
  def self.call(user, id)
    user.maps.find(id)
  end
end
