module Tools
  class UpdateWorkOrderStatus < BaseTool
    def name
      "constitution.update_work_order_status"
    end

    def definition
      {
        name: name,
        description: "Update the status of a work order",
        inputSchema: {
          type: "object",
          properties: {
            api_token: { type: "string", description: "API authentication token" },
            project_id: { type: "integer", description: "Project ID" },
            work_order_id: { type: "integer", description: "Work order ID" },
            status: { type: "string", description: "New status", enum: %w[backlog todo in_progress review done] }
          },
          required: [ "api_token", "project_id", "work_order_id", "status" ]
        }
      }
    end

    def call(arguments)
      user = authenticate!(arguments)
      project = find_project(user, arguments["project_id"])
      wo = project.work_orders.find(arguments["work_order_id"])
      wo.update!(status: arguments["status"])
      { id: wo.id, title: wo.title, status: wo.status, message: "Status updated to #{wo.status}" }
    end
  end
end
