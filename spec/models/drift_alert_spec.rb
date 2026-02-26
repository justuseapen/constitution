require "rails_helper"

RSpec.describe DriftAlert, type: :model do
  it { should belong_to(:project) }
  it { should define_enum_for(:status).with_values(open: 0, acknowledged: 1, resolved: 2) }
  it { should validate_presence_of(:message) }

  describe ".unresolved" do
    it "returns only non-resolved alerts" do
      project = create(:project)
      user = create(:user, team: project.team)
      doc = create(:document, project: project, created_by: user)
      bp = create(:blueprint, project: project, created_by: user)

      open_alert = DriftAlert.create!(project: project, source: doc, target: bp, message: "Test", status: :open)
      DriftAlert.create!(project: project, source: doc, target: bp, message: "Resolved", status: :resolved)

      expect(DriftAlert.unresolved).to contain_exactly(open_alert)
    end
  end
end
