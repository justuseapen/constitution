require "rails_helper"

RSpec.describe GenerateRequirementsJob, type: :job do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, indexing_status: :indexed) }

  before do
    allow(GraphService).to receive(:create_node)
    allow(GraphService).to receive(:create_edge)

    Project.seed_documents(project, user)

    file = create(:codebase_file, repository: repository, path: "app/models/user.rb", language: "ruby")
    create(:extracted_artifact, codebase_file: file, artifact_type: :data_model, name: "User")
    create(:extracted_artifact, codebase_file: file, artifact_type: :route, name: "GET /users")

    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(status: 200, body: {
        choices: [{ message: { content: "<h2>Overview</h2><p>AI-generated content</p>" } }]
      }.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "updates the existing product_overview document in-place" do
    expect(project.documents.product_overview.count).to eq(1)
    original_doc = project.documents.find_by(document_type: :product_overview)
    original_id = original_doc.id

    GenerateRequirementsJob.perform_now(project_id: project.id, user_id: user.id, repository_id: repository.id)

    expect(project.documents.product_overview.count).to eq(1)
    updated_doc = project.documents.find_by(document_type: :product_overview)
    expect(updated_doc.id).to eq(original_id)
    expect(updated_doc.body).to include("AI-generated content")
    expect(updated_doc.status).to eq("ai_generated")
  end

  it "updates the existing technical_requirement document in-place" do
    expect(project.documents.technical_requirement.count).to eq(1)

    GenerateRequirementsJob.perform_now(project_id: project.id, user_id: user.id, repository_id: repository.id)

    expect(project.documents.technical_requirement.count).to eq(1)
    doc = project.documents.find_by(document_type: :technical_requirement)
    expect(doc.body).to include("AI-generated content")
  end

  it "creates a version snapshot before updating" do
    GenerateRequirementsJob.perform_now(project_id: project.id, user_id: user.id, repository_id: repository.id)

    doc = project.documents.find_by(document_type: :product_overview)
    expect(doc.versions.count).to eq(1)
    expect(doc.versions.first.body_snapshot).to include("Business Problem")
  end

  it "creates documents if none exist for that type" do
    project.documents.destroy_all

    GenerateRequirementsJob.perform_now(project_id: project.id, user_id: user.id, repository_id: repository.id)

    expect(project.documents.product_overview.count).to eq(1)
    expect(project.documents.technical_requirement.count).to eq(1)
  end

  it "requeues if repository is still indexing" do
    repository.update!(indexing_status: :indexing)

    expect {
      GenerateRequirementsJob.perform_now(project_id: project.id, user_id: user.id, repository_id: repository.id)
    }.to have_enqueued_job(GenerateRequirementsJob)
  end
end
