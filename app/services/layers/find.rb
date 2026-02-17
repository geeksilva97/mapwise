class Layers::Find
  def self.call(map, id)
    map.layers.find(id)
  end
end
