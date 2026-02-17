class MapStyles::Destroy
  def self.call(user, id)
    style = ::MapStyle.for_user(user).find(id)

    if style.system_default?
      { error: "Cannot delete system presets." }
    else
      style.destroy
      style
    end
  end
end
