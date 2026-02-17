class Markers::Find
  def self.call(map, id)
    map.markers.find(id)
  end
end
