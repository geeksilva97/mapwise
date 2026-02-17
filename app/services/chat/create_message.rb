class Chat::CreateMessage
  def self.call(map, content)
    message = map.chat_messages.build(role: "user", content: content)
    message.save
    message
  end
end
