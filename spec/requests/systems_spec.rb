require "rails_helper"

RSpec.describe "Systems", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }

  before do
    sign_in user
    allow(GraphService).to receive(:create_node)
  end

  describe "GET /systems" do
    it "shows system map" do
      create(:service_system, team: team, name: "API Gateway")
      get systems_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("API Gateway")
    end

    it "returns JSON with nodes and edges" do
      sys1 = create(:service_system, team: team, name: "Orders")
      sys2 = create(:service_system, team: team, name: "Payments")
      allow(GraphService).to receive(:create_edge)
      create(:system_dependency, source_system: sys1, target_system: sys2)

      get systems_path(format: :json)
      json = JSON.parse(response.body)
      expect(json["nodes"].length).to eq(2)
      expect(json["edges"].length).to eq(1)
    end
  end

  describe "POST /systems" do
    it "creates a system" do
      expect {
        post systems_path, params: { service_system: { name: "New Service", system_type: "service" } }
      }.to change(ServiceSystem, :count).by(1)
      expect(response).to redirect_to(systems_path)
    end
  end

  describe "DELETE /systems/:id" do
    it "deletes a system" do
      sys = create(:service_system, team: team)
      expect {
        delete system_path(sys)
      }.to change(ServiceSystem, :count).by(-1)
    end
  end
end
