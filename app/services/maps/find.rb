class Maps::Find
  def self.call(workspace, id)
    workspace.maps.find(id)
  end
end
