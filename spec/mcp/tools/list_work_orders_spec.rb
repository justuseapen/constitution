require "rails_helper"
require_relative "../../../app/mcp/tools/base_tool"
require_relative "../../../app/mcp/tools/list_work_orders"

RSpec.describe Tools::ListWorkOrders do
  let(:tool) { Tools::ListWorkOrders.new }

  describe "#definition" do
    it "returns proper MCP tool definition" do
      defn = tool.definition
      expect(defn[:name]).to eq("constitution.list_work_orders")
      expect(defn[:inputSchema][:required]).to include("api_token", "project_id")
    end
  end

  describe "#name" do
    it "returns the tool name" do
      expect(tool.name).to eq("constitution.list_work_orders")
    end
  end
end
