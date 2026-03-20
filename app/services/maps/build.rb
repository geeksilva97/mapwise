class Maps::Build
  def self.call(workspace, user, params = {})
    map = workspace.maps.build(params)
    map.user = user
    map
  end
end
