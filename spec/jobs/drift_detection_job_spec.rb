require "rails_helper"

RSpec.describe DriftDetectionJob, type: :job do
  describe "#perform" do
    context "when Neo4j is not available" do
      before { allow(GraphService).to receive(:available?).and_return(false) }

      it "skips gracefully" do
        expect(GraphService).not_to receive(:execute)
        DriftDetectionJob.perform_now
      end
    end

    context "when Neo4j is available" do
      let(:project) { create(:project) }
      let(:user) { create(:user, team: project.team) }

      before do
        allow(GraphService).to receive(:available?).and_return(true)
      end

      it "creates a drift alert when a document is newer than its linked blueprint" do
        doc = create(:document, project: project, created_by: user, updated_at: 1.hour.ago)
        bp = create(:blueprint, project: project, created_by: user, updated_at: 2.days.ago)

        allow(GraphService).to receive(:execute)
          .with(/Document.*DEFINES_FEATURE.*Blueprint/, any_args)
          .and_return([ { doc_id: doc.id, bp_id: bp.id } ])

        allow(GraphService).to receive(:execute)
          .with(/Blueprint.*IMPLEMENTED_BY.*WorkOrder/, any_args)
          .and_return([])

        expect { DriftDetectionJob.perform_now }.to change(DriftAlert, :count).by(1)
        alert = DriftAlert.last
        expect(alert.source_type).to eq("Document")
        expect(alert.source_id).to eq(doc.id)
        expect(alert.target_type).to eq("Blueprint")
        expect(alert.target_id).to eq(bp.id)
        expect(alert.message).to include("updated since")
        expect(alert.status).to eq("open")
      end

      it "does not create duplicate alerts" do
        doc = create(:document, project: project, created_by: user, updated_at: 1.hour.ago)
        bp = create(:blueprint, project: project, created_by: user, updated_at: 2.days.ago)

        allow(GraphService).to receive(:execute)
          .with(/Document.*DEFINES_FEATURE.*Blueprint/, any_args)
          .and_return([ { doc_id: doc.id, bp_id: bp.id } ])
        allow(GraphService).to receive(:execute)
          .with(/Blueprint.*IMPLEMENTED_BY.*WorkOrder/, any_args)
          .and_return([])

        DriftDetectionJob.perform_now
        expect { DriftDetectionJob.perform_now }.not_to change(DriftAlert, :count)
      end
    end
  end
end
