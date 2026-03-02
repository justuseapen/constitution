module Tools
  class GetBlueprint < BaseTool
    def name
      "constitution.get_blueprint"
    end

    def definition
      {
        name: name,
        description: "Fetch blueprints for a project, optionally filtered by type",
        inputSchema: {
          type: "object",
          properties: {
            api_token: { type: "string", description: "API authentication token" },
            project_id: { type: "integer", description: "Project ID" },
            blueprint_type: { type: "string", description: "Filter by blueprint type" }
          },
          required: [ "api_token", "project_id" ]
        }
      }
    end

    def call(arguments)
      user = authenticate!(arguments)
      project = find_project(user, arguments["project_id"])
      scope = project.blueprints
      scope = scope.where(blueprint_type: arguments["blueprint_type"]) if arguments["blueprint_type"]
      scope.order(updated_at: :desc).map do |bp|
        { id: bp.id, title: bp.title, blueprint_type: bp.blueprint_type, body: bp.body, document_id: bp.document_id, updated_at: bp.updated_at }
      end
    end
  end
end
