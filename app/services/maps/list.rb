class Maps::List
  def self.call(workspace)
    workspace.maps.order(updated_at: :desc)
  end
end
