require "rails_helper"

RSpec.describe AgentChatJob, type: :job do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }
  let(:document) { create(:document, project: project, created_by: user) }
  let(:conversation) do
    conv = AgentConversation.new(
      conversable: document,
      user: user,
      model_provider: "openrouter"
    )
    conv.write_attribute(:model_name, "anthropic/claude-sonnet-4-5-20250929")
    conv.save!
    conv
  end
  let(:system_prompt) { "You are the Refinery Agent." }

  before do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(status: 200, body: {
        choices: [{ message: { content: "Here is my response." } }]
      }.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "includes the system prompt as the first message" do
    messages_sent = nil
    allow(OPENROUTER_CLIENT).to receive(:chat) do |params|
      messages_sent = params[:parameters][:messages]
      { "choices" => [{ "message" => { "content" => "Response" } }] }
    end

    AgentChatJob.perform_now(
      conversation_id: conversation.id,
      message: "Hello",
      system_prompt: system_prompt
    )

    expect(messages_sent.first[:role]).to eq("system")
    expect(messages_sent.first[:content]).to eq(system_prompt)
  end

  it "saves the user message and assistant response" do
    allow(OPENROUTER_CLIENT).to receive(:chat) do |params|
      stream_proc = params[:parameters][:stream]
      stream_proc.call({ "choices" => [{ "delta" => { "content" => "Response" } }] })
      { "choices" => [{ "message" => { "content" => "Response" } }] }
    end

    AgentChatJob.perform_now(
      conversation_id: conversation.id,
      message: "Hello",
      system_prompt: system_prompt
    )

    expect(conversation.messages.where(role: "user").count).to eq(1)
    expect(conversation.messages.where(role: "assistant").count).to eq(1)
    expect(conversation.messages.where(role: "assistant").last.content).to eq("Response")
  end

  it "broadcasts an error on failure" do
    allow(OPENROUTER_CLIENT).to receive(:chat).and_raise(StandardError, "API error")

    expect(ActionCable.server).to receive(:broadcast).with(
      "agent_chat_Document_#{document.id}",
      hash_including(type: "error")
    )

    AgentChatJob.perform_now(
      conversation_id: conversation.id,
      message: "Hello",
      system_prompt: system_prompt
    )
  end
end
