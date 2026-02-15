class ChatMessagesController < ApplicationController
  before_action :set_map

  def create
    content = params.dig(:chat_message, :content).to_s.strip
    @message = @map.chat_messages.build(role: "user", content: content)

    if @message.save
      AiChatJob.perform_later(@map.id, @message.id)
      head :ok
    else
      render json: { error: @message.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  def clear
    @map.chat_messages.destroy_all
    redirect_to edit_map_path(@map, tab: "ai"), notice: "Chat cleared"
  end

  private

  def set_map
    @map = Current.user.maps.find(params[:map_id])
  end
end
