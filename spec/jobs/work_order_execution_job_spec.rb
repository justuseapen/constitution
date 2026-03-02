require "rails_helper"

RSpec.describe WorkOrderExecutionJob, type: :job do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, indexing_status: :indexed) }
  let(:work_order) { create(:work_order, project: project, status: :todo) }
  let(:execution) { create(:work_order_execution, work_order: work_order, triggered_by: user, status: :queued) }

  it "is enqueued in the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end

  it "marks execution as failed when claude CLI is not found" do
    allow_any_instance_of(described_class).to receive(:claude_available?).and_return(false)

    described_class.perform_now(execution.id)

    execution.reload
    expect(execution.status).to eq("failed")
    expect(execution.error_message).to include("claude CLI not found")
  end

  it "marks execution as failed when no repositories are available" do
    allow_any_instance_of(described_class).to receive(:claude_available?).and_return(true)

    described_class.perform_now(execution.id)

    execution.reload
    expect(execution.status).to eq("failed")
    expect(execution.error_message).to include("No indexed repositories")
  end

  it "updates work order status to review on success" do
    allow_any_instance_of(described_class).to receive(:claude_available?).and_return(true)
    allow_any_instance_of(described_class).to receive(:find_repositories).and_return([repository])
    allow_any_instance_of(described_class).to receive(:prepare_repo)
    allow_any_instance_of(described_class).to receive(:execute_claude).and_return("<constitution>COMPLETE</constitution>")
    allow_any_instance_of(described_class).to receive(:open_pull_request).and_return("https://github.com/example/repo/pull/1")

    described_class.perform_now(execution.id)

    work_order.reload
    expect(work_order.status).to eq("review")
  end

  it "marks execution completed on success signal" do
    allow_any_instance_of(described_class).to receive(:claude_available?).and_return(true)
    allow_any_instance_of(described_class).to receive(:find_repositories).and_return([repository])
    allow_any_instance_of(described_class).to receive(:prepare_repo)
    allow_any_instance_of(described_class).to receive(:execute_claude).and_return("Done.\n<constitution>COMPLETE</constitution>")
    allow_any_instance_of(described_class).to receive(:open_pull_request).and_return("https://github.com/example/repo/pull/1")

    described_class.perform_now(execution.id)

    execution.reload
    expect(execution.status).to eq("completed")
    expect(execution.pull_request_url).to eq("https://github.com/example/repo/pull/1")
    expect(execution.completed_at).to be_present
  end

  it "marks execution failed on failure signal" do
    allow_any_instance_of(described_class).to receive(:claude_available?).and_return(true)
    allow_any_instance_of(described_class).to receive(:find_repositories).and_return([repository])
    allow_any_instance_of(described_class).to receive(:prepare_repo)
    allow_any_instance_of(described_class).to receive(:execute_claude).and_return("<constitution>FAILED: tests won't pass</constitution>")

    described_class.perform_now(execution.id)

    execution.reload
    expect(execution.status).to eq("failed")
    expect(execution.error_message).to include("tests won't pass")
  end
end
