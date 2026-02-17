class Markers::Update
  def self.call(marker, params)
    marker.update(params)
  end
end
