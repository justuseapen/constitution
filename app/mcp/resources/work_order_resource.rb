module Resources
  class WorkOrderResource < BaseResource
    def definition
      { uri: "constitution://work-order/{id}", name: "Work Order", description: "Full work order details", mimeType: "application/json" }
    end

    def matches?(uri)
      uri.match?(%r{^constitution://work-order/\d+$})
    end

    def read(uri)
      wo_id = uri.match(%r{work-order/(\d+)$})[1]
      wo = WorkOrder.find(wo_id)
      {
        id: wo.id, title: wo.title, description: wo.description,
        status: wo.status, priority: wo.priority,
        comments: wo.comments.order(:created_at).map { |c| { body: c.body, author_id: c.user_id } },
        graph_neighbors: GraphService.available? ? GraphService.neighbors("WorkOrder", wo.id) : []
      }
    end
  end
end
