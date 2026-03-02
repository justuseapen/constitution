require "rails_helper"

RSpec.describe GraphExplorerController, type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:service_system) { create(:service_system, team: team, name: "MyService") }
  let(:repository) { create(:repository, service_system: service_system) }

  before { sign_in user }

  describe "GET /graph_explorer" do
    it "renders the explorer page" do
      get graph_explorer_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /graph_explorer/root_nodes" do
    it "returns team service systems as root nodes" do
      service_system # ensure created

      get root_nodes_graph_explorer_path, headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["nodes"].length).to eq(1)
      expect(json["nodes"].first["name"]).to eq("MyService")
      expect(json["nodes"].first["type"]).to eq("ServiceSystem")
    end
  end

  describe "GET /graph_explorer/neighbors" do
    it "returns repositories for a ServiceSystem node" do
      repository # ensure created

      get neighbors_graph_explorer_path, params: { node_type: "ServiceSystem", node_id: service_system.id },
                                         headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["nodes"].length).to eq(1)
      expect(json["nodes"].first["type"]).to eq("Repository")
      expect(json["edges"].length).to eq(1)
    end

    it "returns empty for unknown node types" do
      get neighbors_graph_explorer_path, params: { node_type: "Unknown", node_id: 1 },
                                         headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["nodes"]).to be_empty
    end
  end

  describe "GET /graph_explorer/impact_analysis" do
    it "returns impact data" do
      allow(GraphService).to receive(:available?).and_return(false)

      get impact_analysis_graph_explorer_path, params: { node_type: "ServiceSystem", node_id: service_system.id },
                                               headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json).to have_key("affected")
    end
  end
end
