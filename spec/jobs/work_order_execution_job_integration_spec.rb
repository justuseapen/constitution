require "rails_helper"

RSpec.describe "Work Order Execution Integration", type: :job do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, indexing_status: :indexed) }
  let!(:codebase_file) { create(:codebase_file, repository: repository, path: "app/models/claim.rb") }
  let!(:artifact) { create(:extracted_artifact, codebase_file: codebase_file, artifact_type: :model, name: "Claim") }
  let(:work_order) do
    create(:work_order, project: project, status: :todo,
           title: "Remove claim tracking",
           description: "Remove the Claim model and all associated code")
  end
  let(:execution) { create(:work_order_execution, work_order: work_order, triggered_by: user) }

  it "selects the correct repository based on artifact overlap" do
    builder = WorkOrderPromptBuilder.new(work_order: work_order, repository: nil)
    result = builder.select_repository([repository])
    expect(result).to eq(repository)
  end

  it "builds a prompt containing work order and artifact context" do
    builder = WorkOrderPromptBuilder.new(work_order: work_order, repository: repository)
    prompt = builder.build

    expect(prompt).to include("Remove claim tracking")
    expect(prompt).to include("Claim")
    expect(prompt).to include("app/models/claim.rb")
    expect(prompt).to include("wo-#{work_order.id}")
  end
end
