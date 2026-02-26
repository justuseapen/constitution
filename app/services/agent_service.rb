class AgentService
  def initialize(user:, conversable:, system_prompt:, model: "anthropic/claude-sonnet-4-5-20250929")
    @user = user
    @conversable = conversable
    @system_prompt = system_prompt
    @model = model
    @conversation = find_or_create_conversation
  end

  def chat(message)
    @conversation.messages.create!(role: "user", content: message)

    messages = build_messages
    response = OPENROUTER_CLIENT.chat(
      parameters: {
        model: @model,
        messages: messages
      }
    )

    assistant_content = response.dig("choices", 0, "message", "content")
    @conversation.messages.create!(role: "assistant", content: assistant_content)
    assistant_content
  end

  private

  def find_or_create_conversation
    conv = AgentConversation.find_or_create_by!(
      conversable: @conversable,
      user: @user
    ) do |c|
      c.model_provider = "openrouter"
      c.model_name = @model
    end

    if conv.messages.empty?
      conv.messages.create!(role: "system", content: @system_prompt)
    end

    conv
  end

  def build_messages
    @conversation.messages.order(:created_at).map do |msg|
      { role: msg.role, content: msg.content }
    end
  end
end
