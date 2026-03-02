class SystemDependency < ApplicationRecord
  belongs_to :source_system, class_name: "ServiceSystem"
  belongs_to :target_system, class_name: "ServiceSystem"

  enum :dependency_type, {
    http_api: 0,
    rabbitmq: 1,
    grpc: 2,
    database_shared: 3,
    event_bus: 4,
    sdk: 5
  }

  validates :source_system_id, uniqueness: { scope: [ :target_system_id, :dependency_type ] }

  after_commit :sync_edge_to_graph, on: [ :create, :update ]
  after_commit :remove_edge_from_graph, on: :destroy

  private

  def sync_edge_to_graph
    edge_type = case dependency_type
    when "http_api" then "CALLS_API"
    when "rabbitmq" then "PUBLISHES_TO"
    when "grpc" then "CALLS_GRPC"
    when "database_shared" then "READS_FROM"
    when "event_bus" then "PUBLISHES_TO"
    when "sdk" then "USES_SDK"
    else "DEPENDS_ON"
    end

    GraphService.create_edge(
      from: { label: "System", postgres_id: source_system_id },
      to: { label: "System", postgres_id: target_system_id },
      type: edge_type,
      properties: { dependency_type: dependency_type, metadata: metadata.to_json }
    )
  end

  def remove_edge_from_graph
    GraphService.delete_edge(
      from: { label: "System", postgres_id: source_system_id },
      to: { label: "System", postgres_id: target_system_id },
      type: "DEPENDS_ON"
    )
  end
end
