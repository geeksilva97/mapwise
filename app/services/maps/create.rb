class Maps::Create
  def self.call(user, params)
    map = user.maps.build(params)
    map.save
    map
  end
end
