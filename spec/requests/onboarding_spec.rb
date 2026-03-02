require "rails_helper"

RSpec.describe "Onboarding", type: :request do
  describe "GET /onboarding/new" do
    context "when user has no team" do
      let(:user) { User.create!(name: "Test User", email: "test@example.com", password: "password123") }

      it "shows the onboarding form" do
        sign_in user
        get new_onboarding_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Welcome to Constitution")
        expect(response.body).to include("Team name")
      end
    end

    context "when user already has a team" do
      let(:team) { create(:team) }
      let(:user) { create(:user, team: team) }

      it "redirects to root" do
        sign_in user
        get new_onboarding_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get new_onboarding_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /onboarding" do
    let(:user) { User.create!(name: "Test User", email: "onboard@example.com", password: "password123") }

    before do
      allow(GraphService).to receive(:create_node)
      sign_in user
    end

    it "creates a team and assigns the user" do
      post onboarding_path, params: { team_name: "My Team" }

      user.reload
      expect(user.team).to be_present
      expect(user.team.name).to eq("My Team")
      expect(user.role).to eq("owner")
      expect(response).to redirect_to(root_path)
    end

    it "creates a team and first project" do
      post onboarding_path, params: { team_name: "My Team", project_name: "My Project" }

      user.reload
      expect(user.team.projects.count).to eq(1)
      expect(user.team.projects.first.name).to eq("My Project")
    end

    it "creates team without project when project name is blank" do
      post onboarding_path, params: { team_name: "My Team", project_name: "" }

      user.reload
      expect(user.team).to be_present
      expect(user.team.projects.count).to eq(0)
    end

    it "rejects blank team name" do
      post onboarding_path, params: { team_name: "" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.team).to be_nil
    end
  end

  describe "onboarding redirect" do
    let(:user) { User.create!(name: "Test User", email: "redirect@example.com", password: "password123") }

    it "redirects teamless users to onboarding when accessing projects" do
      sign_in user
      get projects_path
      expect(response).to redirect_to(new_onboarding_path)
    end

    it "does not redirect users with a team" do
      team = create(:team)
      user.update!(team: team)
      sign_in user
      get projects_path
      expect(response).to have_http_status(:ok)
    end
  end
end
