require "rails_helper"

RSpec.describe "Documents", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }

  before { sign_in user }

  describe "GET /projects/:project_id/documents" do
    it "returns http success" do
      get project_documents_path(project)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /projects/:project_id/documents/:id" do
    it "returns http success" do
      document = create(:document, project: project, created_by: user)
      get project_document_path(project, document)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /projects/:project_id/documents" do
    it "creates a document" do
      expect {
        post project_documents_path(project), params: {
          document: { title: "Feature Spec", body: "Content", document_type: "feature_requirement" }
        }
      }.to change(project.documents, :count).by(1)
      expect(response).to redirect_to(project_document_path(project, Document.last))
    end
  end

  describe "PATCH /projects/:project_id/documents/:id" do
    it "updates and creates a version" do
      document = create(:document, project: project, created_by: user, body: "original")
      patch project_document_path(project, document), params: {
        document: { body: "updated content" }
      }
      expect(document.reload.body).to eq("updated content")
      expect(document.versions.count).to eq(1)
    end
  end
end
