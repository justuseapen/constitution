module Resources
  class ProjectRequirements < BaseResource
    def definition
      { uri: "constitution://project/{id}/requirements", name: "Project Requirements", description: "All requirement documents for a project", mimeType: "application/json" }
    end

    def matches?(uri)
      uri.match?(%r{^constitution://project/\d+/requirements$})
    end

    def read(uri)
      project_id = uri.match(%r{project/(\d+)/})[1]
      project = Project.find(project_id)
      project.documents.order(:document_type, :title).map do |doc|
        { id: doc.id, title: doc.title, document_type: doc.document_type, body: doc.body, updated_at: doc.updated_at }
      end
    end
  end
end
