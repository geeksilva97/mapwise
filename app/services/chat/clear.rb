class Chat::Clear
  def self.call(map)
    map.chat_messages.destroy_all
  end
end
