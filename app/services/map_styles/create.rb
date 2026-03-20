class MapStyles::Create
  def self.call(workspace, user, params)
    style = workspace.map_styles.build(params)
    style.user = user
    style.save
    style
  end
end
