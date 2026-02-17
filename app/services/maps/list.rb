class Maps::List
  def self.call(user)
    user.maps.order(updated_at: :desc)
  end
end
