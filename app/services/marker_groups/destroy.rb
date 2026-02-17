class MarkerGroups::Destroy
  def self.call(group)
    group.destroy
  end
end
