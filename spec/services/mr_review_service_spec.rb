require "rails_helper"

RSpec.describe MrReviewService do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, provider: :github, indexing_status: :indexed) }
  let(:work_order) { create(:work_order, project: project, title: "Add login") }
  let(:execution) do
    create(:work_order_execution,
      work_order: work_order,
      triggered_by: user,
      repository: repository,
      status: :completed,
      pull_request_url: "https://github.com/owner/repo/pull/42"
    )
  end

  let(:service) { described_class.new(execution: execution) }

  let(:sample_diff) do
    <<~DIFF
      diff --git a/app/models/user.rb b/app/models/user.rb
      --- a/app/models/user.rb
      +++ b/app/models/user.rb
      @@ -1,3 +1,5 @@
       class User < ApplicationRecord
      +  validates :email, presence: true
      +  validates :name, presence: true
       end
    DIFF
  end

  let(:ai_response) do
    {
      "choices" => [{
        "message" => {
          "content" => '{"overall":"approve","summary":"Looks good","criteria_met":[],"issues":[]}'
        }
      }]
    }
  end

  before do
    provider = instance_double(Vcs::GithubProvider,
      diff: sample_diff,
      post_review: true
    )
    allow(Vcs::ProviderFactory).to receive(:for).and_return(provider)
    allow(OPENROUTER_CLIENT).to receive(:chat).and_return(ai_response)
    allow(GraphService).to receive(:create_node)
  end

  describe "#review!" do
    it "returns review results" do
      result = service.review!
      expect(result).to include(:static, :ai)
      expect(result[:ai][:overall]).to eq("approve")
    end

    it "creates a FeedbackItem" do
      expect { service.review! }.to change(FeedbackItem, :count).by(1)

      feedback = FeedbackItem.last
      expect(feedback.title).to eq("QA Review: Add login")
      expect(feedback.source).to eq("qa_pipeline")
      expect(feedback.technical_context["work_order_id"]).to eq(work_order.id)
    end

    it "posts review to VCS provider" do
      provider = Vcs::ProviderFactory.for(repository)
      service.review!
      expect(provider).to have_received(:post_review).with(
        pr_identifier: "42",
        body: anything
      )
    end

    it "returns nil when PR URL is missing" do
      execution.update!(pull_request_url: nil)
      expect(service.review!).to be_nil
    end

    it "returns nil when diff is empty" do
      provider = instance_double(Vcs::GithubProvider, diff: nil)
      allow(Vcs::ProviderFactory).to receive(:for).and_return(provider)

      expect(service.review!).to be_nil
    end
  end

  describe "static checks" do
    it "warns about large diffs" do
      large_diff = "diff --git a/file.rb b/file.rb\n" + ("+added line\n" * 600)
      provider = instance_double(Vcs::GithubProvider, diff: large_diff, post_review: true)
      allow(Vcs::ProviderFactory).to receive(:for).and_return(provider)

      result = service.review!
      warnings = result[:static].select { |f| f[:severity] == "warning" }
      expect(warnings.any? { |w| w[:message].include?("Large diff") }).to be true
    end
  end
end
