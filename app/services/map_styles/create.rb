class MapStyles::Create
  def self.call(user, params)
    style = user.map_styles.build(params)
    style.save
    style
  end
end
