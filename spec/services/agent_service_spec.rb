require "rails_helper"

RSpec.describe AgentService do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }
  let(:document) { create(:document, project: project, created_by: user) }

  before do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(status: 200, body: {
        choices: [{ message: { content: "Here is my analysis..." } }]
      }.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "sends context to OpenRouter and persists the conversation" do
    service = AgentService.new(
      user: user,
      conversable: document,
      system_prompt: "You are the Refinery Agent."
    )
    response = service.chat("Review this document for gaps")

    expect(response).to include("analysis")
    expect(document.agent_conversations.count).to eq(1)
    expect(document.agent_conversations.first.messages.count).to eq(3) # system + user + assistant
  end

  it "reuses existing conversation" do
    service = AgentService.new(user: user, conversable: document, system_prompt: "Test")
    service.chat("First message")
    service.chat("Second message")

    expect(document.agent_conversations.count).to eq(1)
    expect(document.agent_conversations.first.messages.count).to eq(5) # system + 2 user + 2 assistant
  end
end
