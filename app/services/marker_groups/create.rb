class MarkerGroups::Create
  def self.call(map, params)
    group = map.marker_groups.build(params)
    group.save
    group
  end
end
