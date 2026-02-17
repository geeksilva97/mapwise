class Markers::Create
  def self.call(map, params)
    marker = map.markers.build(params)
    marker.save
    marker
  end
end
