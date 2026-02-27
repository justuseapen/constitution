class JiraImportJob < ApplicationJob
  queue_as :default

  def perform(project_id:, user_id:, jira_url:, jira_email:, jira_token:, jira_project_key:)
    project = Project.find(project_id)
    user = User.find(user_id)

    importer = Importers::JiraImporter.new(
      project: project,
      user: user,
      jira_url: jira_url,
      jira_email: jira_email,
      jira_token: jira_token,
      jira_project_key: jira_project_key
    )

    importer.import!
  end
end
