require "rails_helper"

RSpec.describe WorkOrderExecution, type: :model do
  it { should belong_to(:work_order) }
  it { should belong_to(:repository).optional }
  it { should belong_to(:triggered_by).class_name("User") }

  it { should validate_presence_of(:status) }

  describe "status enum" do
    it { should define_enum_for(:status).with_values(queued: 0, running: 1, completed: 2, failed: 3) }
  end

  describe "concurrent run validation" do
    it "prevents two running executions for the same work order on create" do
      work_order = create(:work_order)
      user = work_order.project.team.users.first || create(:user, team: work_order.project.team)
      create(:work_order_execution, work_order: work_order, triggered_by: user, status: :running)
      duplicate = build(:work_order_execution, work_order: work_order, triggered_by: user, status: :running)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:work_order_id]).to include("already has a running execution")
    end

    it "prevents updating to running when another is already running" do
      work_order = create(:work_order)
      user = work_order.project.team.users.first || create(:user, team: work_order.project.team)
      create(:work_order_execution, work_order: work_order, triggered_by: user, status: :running)
      queued = create(:work_order_execution, work_order: work_order, triggered_by: user, status: :queued)
      queued.status = :running
      expect(queued).not_to be_valid
    end

    it "allows re-saving an existing running execution" do
      execution = create(:work_order_execution, status: :running)
      execution.log = "some output"
      expect(execution).to be_valid
    end
  end

  describe "#duration" do
    it "returns nil when started_at is nil" do
      execution = build(:work_order_execution, started_at: nil)
      expect(execution.duration).to be_nil
    end

    it "returns difference between completed_at and started_at" do
      execution = build(:work_order_execution, started_at: 10.minutes.ago, completed_at: 5.minutes.ago)
      expect(execution.duration).to be_within(1).of(300)
    end

    it "uses Time.current when completed_at is nil" do
      execution = build(:work_order_execution, started_at: 10.minutes.ago, completed_at: nil)
      expect(execution.duration).to be_within(1).of(600)
    end
  end

  describe "#append_log" do
    it "appends text to nil log" do
      execution = create(:work_order_execution)
      execution.append_log("line 1\n")
      expect(execution.reload.log).to eq("line 1\n")
    end

    it "appends text to existing log" do
      execution = create(:work_order_execution, log: "line 1\n")
      execution.append_log("line 2\n")
      expect(execution.reload.log).to eq("line 1\nline 2\n")
    end
  end

  describe ".latest_first" do
    it "orders by created_at descending" do
      old = create(:work_order_execution, created_at: 2.days.ago)
      new_exec = create(:work_order_execution, created_at: 1.day.ago)
      expect(WorkOrderExecution.latest_first).to eq([ new_exec, old ])
    end
  end
end
