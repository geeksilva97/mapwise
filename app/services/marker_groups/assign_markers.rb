class MarkerGroups::AssignMarkers
  def self.call(map, group, marker_ids)
    markers = map.markers.where(id: marker_ids)
    markers.update_all(marker_group_id: group.id, color: group.color)
    markers
  end
end
