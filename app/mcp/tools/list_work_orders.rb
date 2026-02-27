module Tools
  class ListWorkOrders < BaseTool
    def name
      "constitution.list_work_orders"
    end

    def definition
      {
        name: name,
        description: "List work orders for a project, optionally filtered by assignee or status",
        inputSchema: {
          type: "object",
          properties: {
            api_token: { type: "string", description: "API authentication token" },
            project_id: { type: "integer", description: "Project ID" },
            status: { type: "string", description: "Filter by status (backlog, todo, in_progress, review, done)", enum: %w[backlog todo in_progress review done] },
            assignee_id: { type: "integer", description: "Filter by assignee user ID" }
          },
          required: ["api_token", "project_id"]
        }
      }
    end

    def call(arguments)
      user = authenticate!(arguments)
      project = find_project(user, arguments["project_id"])
      scope = project.work_orders
      scope = scope.where(status: arguments["status"]) if arguments["status"]
      scope = scope.where(assignee_id: arguments["assignee_id"]) if arguments["assignee_id"]
      scope.order(updated_at: :desc).limit(50).map do |wo|
        { id: wo.id, title: wo.title, status: wo.status, priority: wo.priority, assignee_id: wo.assignee_id, updated_at: wo.updated_at }
      end
    end
  end
end
