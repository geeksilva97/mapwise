class Layers::Create
  def self.call(map, params)
    layer = map.layers.build(params)
    layer.save
    layer
  end
end
