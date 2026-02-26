class AgentChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "agent_chat_#{params[:conversable_type]}_#{params[:conversable_id]}"
  end
end
