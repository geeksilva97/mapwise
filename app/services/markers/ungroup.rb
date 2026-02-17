class Markers::Ungroup
  def self.call(marker)
    marker.update!(marker_group_id: nil, color: "#FF0000")
  end
end
