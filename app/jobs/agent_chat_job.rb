class AgentChatJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:, message:, system_prompt:)
    conversation = AgentConversation.find(conversation_id)
    conversation.messages.create!(role: "user", content: message)

    messages = conversation.messages.order(:created_at).map { |m| { role: m.role, content: m.content } }

    full_response = ""
    OPENROUTER_CLIENT.chat(
      parameters: {
        model: conversation.model_name,
        messages: messages,
        stream: proc { |chunk|
          delta = chunk.dig("choices", 0, "delta", "content")
          if delta
            full_response += delta
            ActionCable.server.broadcast(
              "agent_chat_#{conversation.conversable_type}_#{conversation.conversable_id}",
              { type: "delta", content: delta }
            )
          end
        }
      }
    )

    conversation.messages.create!(role: "assistant", content: full_response)
    ActionCable.server.broadcast(
      "agent_chat_#{conversation.conversable_type}_#{conversation.conversable_id}",
      { type: "complete" }
    )
  end
end
