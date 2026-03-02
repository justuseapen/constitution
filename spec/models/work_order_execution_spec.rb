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
    it "prevents two running executions for the same work order" do
      work_order = create(:work_order)
      user = work_order.project.team.users.first || create(:user, team: work_order.project.team)
      create(:work_order_execution, work_order: work_order, triggered_by: user, status: :running)
      duplicate = build(:work_order_execution, work_order: work_order, triggered_by: user, status: :running)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:work_order_id]).to include("already has a running execution")
    end
  end
end
