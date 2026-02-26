module GraphSync
  extend ActiveSupport::Concern

  included do
    after_commit :sync_to_graph, on: [:create, :update]
    after_commit :remove_from_graph, on: :destroy
  end

  def graph_label
    self.class.name
  end

  def graph_properties
    { postgres_id: id, title: try(:title) || try(:name) }
  end

  private

  def sync_to_graph
    GraphService.create_node(graph_label, graph_properties)
  end

  def remove_from_graph
    GraphService.delete_node(graph_label, id)
  end
end
