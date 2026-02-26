require "rails_helper"

RSpec.describe ServiceSystem, type: :model do
  it { should validate_presence_of(:name) }
  it { should belong_to(:team) }
  it { should have_many(:outgoing_dependencies) }
  it { should have_many(:incoming_dependencies) }
  it { should have_many(:repositories) }
  it { should define_enum_for(:system_type).with_values(
    service: 0, library: 1, database: 2, queue: 3, external_api: 4
  ) }

  describe "GraphSync" do
    before { allow(GraphService).to receive(:create_node) }

    it "uses 'System' as graph label" do
      system = build(:service_system)
      expect(system.graph_label).to eq("System")
    end
  end
end
