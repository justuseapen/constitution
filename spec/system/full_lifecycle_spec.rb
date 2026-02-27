require "rails_helper"

RSpec.describe "Full Lifecycle", type: :system do
  # NOTE: These tests require a full browser environment (Capybara + headless Chrome)
  # and a running database. They are written as a specification and should be run
  # via: docker compose run --rm web bundle exec rspec spec/system/

  let(:team) { create(:team) }
  let(:user) { create(:user, team: team, password: "password123") }

  before do
    driven_by(:selenium_headless)
  end

  describe "complete project lifecycle" do
    it "walks through requirements to planning to validation" do
      # Step 1: Sign in
      visit new_user_session_path
      fill_in "Email", with: user.email
      fill_in "Password", with: "password123"
      click_button "Log in"
      expect(page).to have_content("Projects")

      # Step 2: Create project (verify placeholder docs generated)
      click_link "New Project"
      fill_in "Name", with: "Test Project"
      fill_in "Description", with: "A test project for smoke testing"
      click_button "Create Project"
      expect(page).to have_content("Test Project")
      expect(page).to have_content("Documents")

      # Verify placeholder docs were created
      project = Project.last
      expect(project.documents.count).to eq(2)
      expect(project.documents.pluck(:title)).to include("Product Overview", "Technical Requirements")

      # Step 3: Navigate to Refinery and edit a document
      visit project_documents_path(project)
      expect(page).to have_content("Product Overview")
      click_link "Product Overview"
      click_link "Edit"
      # Tiptap editor would be tested here in a full browser environment
      # For now, verify the edit page loads
      expect(page).to have_css("[data-controller='tiptap']")

      # Step 4: Create a Feature Blueprint linked to the document
      visit project_blueprints_path(project)
      click_link "New Blueprint"
      fill_in "Title", with: "Authentication Architecture"
      # Select blueprint type and submit
      click_button "Create Blueprint"
      expect(page).to have_content("Authentication Architecture")

      # Step 5: Navigate to Planner and create a work order
      visit project_work_orders_path(project)
      click_link "New Work Order"
      fill_in "Title", with: "Implement Login Form"
      click_button "Create Work Order"
      expect(page).to have_content("Implement Login Form")

      # Step 6: Verify the kanban board shows the work order
      visit project_work_orders_path(project)
      expect(page).to have_content("Implement Login Form")
      expect(page).to have_css("[data-controller='kanban']")

      # Step 7: Visit the dashboard
      visit project_path(project)
      expect(page).to have_content("Test Project")
      expect(page).to have_content("Documents")
      expect(page).to have_content("Open Work Orders")
    end
  end

  describe "feedback lifecycle" do
    it "receives feedback via API and displays in inbox" do
      project = create(:project, team: team)
      app_key = create(:app_key, project: project)

      # Submit feedback via API
      post "/api/v1/feedback",
        params: { title: "Login is broken", body: "500 error on submit" },
        headers: { "Authorization" => "Bearer #{app_key.token}" }

      expect(response).to have_http_status(:created)

      # View in Validator inbox
      sign_in user
      visit project_feedback_items_path(project)
      expect(page).to have_content("Login is broken")
    end
  end

  describe "notification lifecycle" do
    it "shows notification bell and recent notifications" do
      sign_in user

      # Create a notification
      create(:notification, user: user, message: "New drift alert detected")

      visit projects_path
      expect(page).to have_css("[data-controller='notifications']")
    end
  end
end
