class GitImportJob < ApplicationJob
  queue_as :default

  def perform(project_id:, user_id:, url:, service_system_id: nil)
    project = Project.find(project_id)
    user = User.find(user_id)
    service_system = service_system_id ? ServiceSystem.find(service_system_id) : nil

    importer = Importers::GitImporter.new(
      project: project,
      user: user,
      url: url,
      service_system: service_system
    )

    repository = importer.import!
  end
end
