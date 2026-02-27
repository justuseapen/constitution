module Tools
  class GetRequirements < BaseTool
    def name
      "constitution.get_requirements"
    end

    def definition
      {
        name: name,
        description: "Fetch requirement documents for a project, optionally filtered by type",
        inputSchema: {
          type: "object",
          properties: {
            api_token: { type: "string", description: "API authentication token" },
            project_id: { type: "integer", description: "Project ID" },
            document_type: { type: "string", description: "Filter by document type" }
          },
          required: ["api_token", "project_id"]
        }
      }
    end

    def call(arguments)
      user = authenticate!(arguments)
      project = find_project(user, arguments["project_id"])
      scope = project.documents
      scope = scope.where(document_type: arguments["document_type"]) if arguments["document_type"]
      scope.order(updated_at: :desc).map do |doc|
        { id: doc.id, title: doc.title, document_type: doc.document_type, body: doc.body, updated_at: doc.updated_at }
      end
    end
  end
end
