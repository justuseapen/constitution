module Tools
  class GetWorkOrder < BaseTool
    def name
      "constitution.get_work_order"
    end

    def definition
      {
        name: name,
        description: "Get full details of a work order including description and linked artifacts",
        inputSchema: {
          type: "object",
          properties: {
            api_token: { type: "string", description: "API authentication token" },
            project_id: { type: "integer", description: "Project ID" },
            work_order_id: { type: "integer", description: "Work order ID" }
          },
          required: ["api_token", "project_id", "work_order_id"]
        }
      }
    end

    def call(arguments)
      user = authenticate!(arguments)
      project = find_project(user, arguments["project_id"])
      wo = project.work_orders.find(arguments["work_order_id"])
      {
        id: wo.id, title: wo.title, description: wo.description,
        status: wo.status, priority: wo.priority,
        assignee_id: wo.assignee_id, phase_id: wo.phase_id,
        created_at: wo.created_at, updated_at: wo.updated_at,
        comments: wo.comments.order(:created_at).map { |c| { id: c.id, body: c.body, author_id: c.user_id, created_at: c.created_at } },
        graph_neighbors: GraphService.available? ? GraphService.neighbors("WorkOrder", wo.id) : []
      }
    end
  end
end
