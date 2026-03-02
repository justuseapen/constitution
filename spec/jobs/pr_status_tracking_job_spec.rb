require "rails_helper"

RSpec.describe PrStatusTrackingJob, type: :job do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, provider: :github, indexing_status: :indexed) }
  let(:work_order) { create(:work_order, project: project, title: "Test feature") }

  it "is enqueued in the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end

  it "updates PR status from VCS provider" do
    execution = create(:work_order_execution,
      work_order: work_order,
      triggered_by: user,
      repository: repository,
      status: :completed,
      pull_request_url: "https://github.com/owner/repo/pull/42",
      pr_status: :pr_open
    )

    provider = instance_double(Vcs::GithubProvider, pr_status: :merged)
    allow(Vcs::ProviderFactory).to receive(:for).and_return(provider)

    described_class.perform_now

    execution.reload
    expect(execution.pr_status).to eq("pr_merged")
  end

  it "creates notification when PR is merged" do
    execution = create(:work_order_execution,
      work_order: work_order,
      triggered_by: user,
      repository: repository,
      status: :completed,
      pull_request_url: "https://github.com/owner/repo/pull/42",
      pr_status: :pr_open
    )

    provider = instance_double(Vcs::GithubProvider, pr_status: :merged)
    allow(Vcs::ProviderFactory).to receive(:for).and_return(provider)

    expect { described_class.perform_now }.to change(Notification, :count).by(1)
  end

  it "skips executions without PR URLs" do
    create(:work_order_execution,
      work_order: work_order,
      triggered_by: user,
      status: :completed,
      pull_request_url: nil
    )

    expect(Vcs::ProviderFactory).not_to receive(:for)
    described_class.perform_now
  end

  it "does not update if status is unchanged" do
    execution = create(:work_order_execution,
      work_order: work_order,
      triggered_by: user,
      repository: repository,
      status: :completed,
      pull_request_url: "https://github.com/owner/repo/pull/42",
      pr_status: :pr_open
    )

    provider = instance_double(Vcs::GithubProvider, pr_status: :open)
    allow(Vcs::ProviderFactory).to receive(:for).and_return(provider)

    expect { described_class.perform_now }.not_to change(Notification, :count)
  end
end
