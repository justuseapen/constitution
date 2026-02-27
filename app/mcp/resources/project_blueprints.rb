module Resources
  class ProjectBlueprints < BaseResource
    def definition
      { uri: "constitution://project/{id}/blueprints", name: "Project Blueprints", description: "All blueprints for a project", mimeType: "application/json" }
    end

    def matches?(uri)
      uri.match?(%r{^constitution://project/\d+/blueprints$})
    end

    def read(uri)
      project_id = uri.match(%r{project/(\d+)/})[1]
      project = Project.find(project_id)
      project.blueprints.order(:blueprint_type, :title).map do |bp|
        { id: bp.id, title: bp.title, blueprint_type: bp.blueprint_type, body: bp.body, document_id: bp.document_id, updated_at: bp.updated_at }
      end
    end
  end
end
