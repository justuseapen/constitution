class DocumentChannel < ApplicationCable::Channel
  def subscribed
    stream_from "document_#{params[:document_id]}"
    broadcast_presence(:joined)
  end

  def unsubscribed
    broadcast_presence(:left)
  end

  private

  def broadcast_presence(action)
    ActionCable.server.broadcast(
      "document_#{params[:document_id]}",
      { type: "presence", action: action, user: { id: current_user.id, name: current_user.name } }
    )
  end
end
