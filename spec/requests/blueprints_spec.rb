require "rails_helper"

RSpec.describe "Blueprints", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }

  before { sign_in user }

  describe "GET /projects/:project_id/blueprints" do
    it "returns http success" do
      get project_blueprints_path(project)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /projects/:project_id/blueprints/:id" do
    it "returns http success" do
      blueprint = create(:blueprint, project: project, created_by: user)
      get project_blueprint_path(project, blueprint)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /projects/:project_id/blueprints" do
    it "creates a blueprint" do
      expect {
        post project_blueprints_path(project), params: {
          blueprint: { title: "System Architecture", body: "Content", blueprint_type: "system_diagram" }
        }
      }.to change(project.blueprints, :count).by(1)
      expect(response).to redirect_to(project_blueprint_path(project, Blueprint.last))
    end

    it "creates a blueprint with document association" do
      document = create(:document, project: project, created_by: user)
      post project_blueprints_path(project), params: {
        blueprint: { title: "Feature Blueprint", body: "Content", blueprint_type: "feature_blueprint", document_id: document.id }
      }
      expect(Blueprint.last.document).to eq(document)
    end
  end

  describe "PATCH /projects/:project_id/blueprints/:id" do
    it "updates and creates a version" do
      blueprint = create(:blueprint, project: project, created_by: user, body: "original")
      patch project_blueprint_path(project, blueprint), params: {
        blueprint: { body: "updated content" }
      }
      expect(blueprint.reload.body).to eq("updated content")
      expect(blueprint.versions.count).to eq(1)
    end
  end

  describe "DELETE /projects/:project_id/blueprints/:id" do
    it "deletes a blueprint" do
      blueprint = create(:blueprint, project: project, created_by: user)
      expect {
        delete project_blueprint_path(project, blueprint)
      }.to change(project.blueprints, :count).by(-1)
      expect(response).to redirect_to(project_blueprints_path(project))
    end
  end
end
