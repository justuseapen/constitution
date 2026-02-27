module Tools
  class GetImpactAnalysis < BaseTool
    def name
      "constitution.get_impact_analysis"
    end

    def definition
      {
        name: name,
        description: "Traverse the knowledge graph to find downstream impact of a change to a node",
        inputSchema: {
          type: "object",
          properties: {
            api_token: { type: "string", description: "API authentication token" },
            node_type: { type: "string", description: "Type of node (Document, Blueprint, WorkOrder, System)", enum: %w[Document Blueprint WorkOrder System] },
            node_id: { type: "integer", description: "Node ID" },
            depth: { type: "integer", description: "How many hops to traverse (default: 3)" }
          },
          required: ["api_token", "node_type", "node_id"]
        }
      }
    end

    def call(arguments)
      authenticate!(arguments)
      return { error: "Neo4j not available" } unless GraphService.available?

      depth = arguments["depth"] || 3
      results = GraphService.impact_analysis(arguments["node_type"], arguments["node_id"], depth: depth)
      {
        source: { type: arguments["node_type"], id: arguments["node_id"] },
        impacted_nodes: results,
        depth: depth
      }
    end
  end
end
