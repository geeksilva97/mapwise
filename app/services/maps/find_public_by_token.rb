class Maps::FindPublicByToken
  def self.call(token)
    ::Map.find_public_by_token(token)
  end
end
