class Maps::Build
  def self.call(user, params = {})
    user.maps.build(params)
  end
end
