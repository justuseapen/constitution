module Tools
  class GetSystemDependencies < BaseTool
    def name
      "constitution.get_system_dependencies"
    end

    def definition
      {
        name: name,
        description: "Get dependency graph for a service system from Neo4j",
        inputSchema: {
          type: "object",
          properties: {
            api_token: { type: "string", description: "API authentication token" },
            system_id: { type: "integer", description: "ServiceSystem ID" }
          },
          required: ["api_token", "system_id"]
        }
      }
    end

    def call(arguments)
      user = authenticate!(arguments)
      system = user.team.service_systems.find(arguments["system_id"])
      {
        system: { id: system.id, name: system.name, system_type: system.system_type },
        outgoing: system.outgoing_dependencies.map { |d| { target_id: d.target_system_id, type: d.dependency_type, metadata: d.metadata } },
        incoming: system.incoming_dependencies.map { |d| { source_id: d.source_system_id, type: d.dependency_type, metadata: d.metadata } },
        graph_neighbors: GraphService.available? ? GraphService.neighbors("System", system.id) : []
      }
    end
  end
end
