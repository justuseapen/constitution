class AgentChatsController < ApplicationController
  before_action :authenticate_user!

  def index
    conversation = AgentConversation.find_by(
      conversable_type: params[:conversable_type],
      conversable_id: params[:conversable_id],
      user: current_user
    )

    messages = if conversation
      conversation.messages.where.not(role: "system").order(:created_at).map do |m|
        { role: m.role, content: m.content, created_at: m.created_at }
      end
    else
      []
    end

    render json: { messages: messages }
  end

  def create
    conversable = params[:conversable_type].constantize.find(params[:conversable_id])
    conversation = AgentConversation.find_or_create_by!(
      conversable: conversable, user: current_user
    ) do |c|
      c.model_provider = "openrouter"
      c.model_name = "anthropic/claude-sonnet-4-5-20250929"
    end

    system_prompt = agent_system_prompt(conversable)
    AgentChatJob.perform_later(
      conversation_id: conversation.id,
      message: params[:message],
      system_prompt: system_prompt
    )

    head :accepted
  end

  private

  def agent_system_prompt(conversable)
    case conversable
    when Document
      "You are the Refinery Agent. Help the user refine requirements, identify gaps, resolve ambiguity, and improve document quality. Focus on making requirements clear, testable, and complete."
    when Blueprint
      "You are the Foundry Agent. Help the user design and refine technical blueprints. Suggest architectural improvements, identify missing components, and ensure alignment with requirements."
    when WorkOrder
      "You are the Planner Agent. Help the user refine work orders, improve acceptance criteria, suggest implementation approaches, and ensure work orders are well-scoped and actionable."
    else
      "You are a helpful assistant for the Constitution SDLC platform."
    end
  end
end
