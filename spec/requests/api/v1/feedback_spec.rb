require "rails_helper"
RSpec.describe "Feedback API", type: :request do
  let(:project) { create(:project) }
  let(:app_key) { create(:app_key, project: project) }

  before { allow(GraphService).to receive(:create_node) }

  describe "POST /api/v1/feedback" do
    it "creates a feedback item with valid app key" do
      post "/api/v1/feedback", params: {
        title: "Checkout broken", body: "500 error on submit",
        technical_context: { browser: "Chrome", url: "/checkout" }
      }, headers: { "Authorization" => "Bearer #{app_key.token}" }
      expect(response).to have_http_status(:created)
      expect(FeedbackItem.last.title).to eq("Checkout broken")
    end

    it "rejects invalid app key" do
      post "/api/v1/feedback", params: { title: "Test" },
        headers: { "Authorization" => "Bearer invalid" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
