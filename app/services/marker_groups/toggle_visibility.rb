class MarkerGroups::ToggleVisibility
  def self.call(group)
    group.update!(visible: !group.visible)
  end
end
