require "rails_helper"

RSpec.describe Importers::JiraImporter do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }

  let(:jira_response) do
    {
      "total" => 2,
      "issues" => [
        {
          "key" => "PROJ-1",
          "fields" => {
            "summary" => "Epic: User Authentication",
            "description" => { "type" => "doc", "content" => [ { "type" => "paragraph", "content" => [ { "type" => "text", "text" => "Auth epic" } ] } ] },
            "issuetype" => { "name" => "Epic" },
            "status" => { "name" => "In Progress" },
            "priority" => { "name" => "High" }
          }
        },
        {
          "key" => "PROJ-2",
          "fields" => {
            "summary" => "Implement login form",
            "description" => { "type" => "doc", "content" => [ { "type" => "paragraph", "content" => [ { "type" => "text", "text" => "Build login" } ] } ] },
            "issuetype" => { "name" => "Story" },
            "status" => { "name" => "To Do" },
            "priority" => { "name" => "Medium" },
            "parent" => { "key" => "PROJ-1" }
          }
        }
      ]
    }
  end

  describe "#import!" do
    before do
      stub_request(:get, /jira\.example\.com/)
        .to_return(status: 200, body: jira_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "creates phases from epics and work orders from stories" do
      importer = Importers::JiraImporter.new(
        project: project,
        user: user,
        jira_url: "https://jira.example.com",
        jira_email: "user@example.com",
        jira_token: "token123",
        jira_project_key: "PROJ"
      )

      importer.import!

      expect(project.phases.count).to eq(1)
      expect(project.phases.first.name).to eq("Epic: User Authentication")
      expect(project.work_orders.count).to eq(1)
      expect(project.work_orders.first.title).to eq("Implement login form")
      expect(project.work_orders.first.status).to eq("todo")
    end
  end
end
