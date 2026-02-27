require "rails_helper"

RSpec.describe "Projects", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }

  before { sign_in user }

  describe "GET /projects" do
    it "returns http success" do
      get projects_path
      expect(response).to have_http_status(:success)
    end

    it "shows only team projects" do
      project = create(:project, team: team)
      other_project = create(:project)
      get projects_path
      expect(response.body).to include(project.name)
      expect(response.body).not_to include(other_project.name)
    end
  end

  describe "GET /projects/new" do
    it "returns http success" do
      get new_project_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /projects/:id" do
    it "returns http success" do
      project = create(:project, team: team)
      get project_path(project)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /projects" do
    it "creates a project for the current team" do
      expect {
        post projects_path, params: { project: { name: "New Project", description: "Test" } }
      }.to change(team.projects, :count).by(1)
      expect(response).to redirect_to(project_path(Project.last))
    end
  end
end
