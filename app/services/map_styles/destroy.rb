class MapStyles::Destroy
  def self.call(workspace, id)
    style = ::MapStyle.for_workspace(workspace).find(id)

    if style.system_default?
      { error: "Cannot delete system presets." }
    else
      style.destroy
      style
    end
  end
end
