require "rails_helper"

RSpec.describe PrValidationJob, type: :job do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, provider: :github, indexing_status: :indexed) }
  let(:work_order) { create(:work_order, project: project, title: "Add feature") }
  let(:execution) do
    create(:work_order_execution,
      work_order: work_order,
      triggered_by: user,
      repository: repository,
      status: :completed,
      pull_request_url: "https://github.com/owner/repo/pull/42"
    )
  end

  it "is enqueued in the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end

  it "calls MrReviewService for eligible executions" do
    review_service = instance_double(MrReviewService, review!: { static: [], ai: { overall: "approve", summary: "Looks good" } })
    allow(MrReviewService).to receive(:new).and_return(review_service)

    described_class.perform_now(execution.id)

    expect(MrReviewService).to have_received(:new).with(execution: execution)
    expect(review_service).to have_received(:review!)
  end

  it "creates a notification on successful review" do
    review_service = instance_double(MrReviewService, review!: { static: [], ai: { overall: "approve", summary: "Looks good" } })
    allow(MrReviewService).to receive(:new).and_return(review_service)

    expect { described_class.perform_now(execution.id) }.to change(Notification, :count).by(1)
  end

  it "skips non-completed executions" do
    execution.update!(status: :running, pull_request_url: nil)
    expect(MrReviewService).not_to receive(:new)
    described_class.perform_now(execution.id)
  end

  it "handles review service errors gracefully" do
    allow(MrReviewService).to receive(:new).and_raise(StandardError, "API down")

    expect { described_class.perform_now(execution.id) }.not_to raise_error
  end
end
