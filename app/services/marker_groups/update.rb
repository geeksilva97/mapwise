class MarkerGroups::Update
  def self.call(group, params)
    group.update(params)
  end
end
