class Layers::ToggleVisibility
  def self.call(layer)
    layer.update!(visible: !layer.visible)
  end
end
