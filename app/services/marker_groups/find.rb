class MarkerGroups::Find
  def self.call(map, id)
    map.marker_groups.find(id)
  end
end
