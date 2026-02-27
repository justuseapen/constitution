require "rails_helper"

RSpec.describe "AgentChats", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }
  let(:document) { create(:document, project: project, created_by: user) }

  before { sign_in user }

  describe "POST /agent_chats" do
    it "creates a conversation and enqueues a chat job" do
      expect {
        post agent_chats_path, params: {
          conversable_type: "Document",
          conversable_id: document.id,
          message: "Review this document"
        }, as: :json
      }.to have_enqueued_job(AgentChatJob)

      expect(response).to have_http_status(:accepted)
      expect(AgentConversation.count).to eq(1)
    end
  end

  describe "GET /agent_chats" do
    it "returns conversation messages for a conversable" do
      conversation = AgentConversation.create!(
        conversable: document, user: user,
        model_provider: "openrouter", model_name: "test"
      )
      conversation.messages.create!(role: "user", content: "Hello")
      conversation.messages.create!(role: "assistant", content: "Hi there")

      get agent_chats_path, params: {
        conversable_type: "Document",
        conversable_id: document.id
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["messages"].length).to eq(2)
      expect(json["messages"][0]["role"]).to eq("user")
      expect(json["messages"][0]["content"]).to eq("Hello")
      expect(json["messages"][1]["role"]).to eq("assistant")
      expect(json["messages"][1]["content"]).to eq("Hi there")
    end

    it "returns empty messages when no conversation exists" do
      get agent_chats_path, params: {
        conversable_type: "Document",
        conversable_id: document.id
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["messages"]).to eq([])
    end
  end
end
