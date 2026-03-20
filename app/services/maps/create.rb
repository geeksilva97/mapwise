class Maps::Create
  def self.call(workspace, user, params)
    map = workspace.maps.build(params)
    map.user = user
    map.save
    map
  end
end
