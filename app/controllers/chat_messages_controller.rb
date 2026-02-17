class ChatMessagesController < ApplicationController
  before_action :set_map

  def create
    content = params.dig(:chat_message, :content).to_s.strip
    @message = Chat::CreateMessage.call(@map, content)

    if @message.persisted?
      AiChatJob.perform_later(@map.id, @message.id)
      head :ok
    else
      render json: { error: @message.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  def clear
    Chat::Clear.call(@map)
    redirect_to edit_map_path(@map, tab: "ai"), notice: "Chat cleared"
  end

  private

  def set_map
    @map = Maps::Find.call(Current.user, params[:map_id])
  end
end
