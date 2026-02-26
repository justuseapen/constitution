require "rails_helper"

RSpec.describe SystemDependency, type: :model do
  it { should belong_to(:source_system).class_name("ServiceSystem") }
  it { should belong_to(:target_system).class_name("ServiceSystem") }
  it { should define_enum_for(:dependency_type).with_values(
    http_api: 0, rabbitmq: 1, grpc: 2, database_shared: 3, event_bus: 4, sdk: 5
  ) }

  describe "graph sync" do
    before do
      allow(GraphService).to receive(:create_node)
      allow(GraphService).to receive(:create_edge)
    end

    it "creates a Neo4j edge on create" do
      dep = create(:system_dependency)
      expect(GraphService).to have_received(:create_edge)
    end
  end
end
