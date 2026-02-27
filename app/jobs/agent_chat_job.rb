class AgentChatJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:, message:, system_prompt:)
    conversation = AgentConversation.find(conversation_id)
    conversation.messages.create!(role: "user", content: message)

    channel = "agent_chat_#{conversation.conversable_type}_#{conversation.conversable_id}"

    messages = [{ role: "system", content: system_prompt }]
    messages += conversation.messages.order(:created_at).map { |m| { role: m.role, content: m.content } }

    full_response = ""
    OPENROUTER_CLIENT.chat(
      parameters: {
        model: conversation.model_name,
        messages: messages,
        stream: proc { |chunk|
          delta = chunk.dig("choices", 0, "delta", "content")
          if delta
            full_response += delta
            ActionCable.server.broadcast(channel, { type: "delta", content: delta })
          end
        }
      }
    )

    conversation.messages.create!(role: "assistant", content: full_response)
    ActionCable.server.broadcast(channel, { type: "complete" })
  rescue StandardError => e
    Rails.logger.error("AgentChatJob failed: #{e.message}")
    channel = "agent_chat_#{AgentConversation.find(conversation_id).then { |c| "#{c.conversable_type}_#{c.conversable_id}" }}" rescue nil
    if channel
      ActionCable.server.broadcast(channel, { type: "error", content: "Sorry, something went wrong. Please try again." })
    end
  end
end
