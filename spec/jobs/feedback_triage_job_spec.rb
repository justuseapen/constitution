require "rails_helper"
RSpec.describe FeedbackTriageJob, type: :job do
  before { allow(GraphService).to receive(:create_node) }

  it "categorizes feedback via AI" do
    feedback = create(:feedback_item, category: :uncategorized)
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(body: { choices: [{ message: { content: '{"category":"bug","score":8}' } }] }.to_json,
                 headers: { "Content-Type" => "application/json" })
    FeedbackTriageJob.perform_now(feedback.id)
    feedback.reload
    expect(feedback.category).to eq("bug")
    expect(feedback.score).to eq(8)
  end
end
