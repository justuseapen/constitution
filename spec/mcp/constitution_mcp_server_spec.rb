require "rails_helper"

# Load MCP server classes
require_relative "../../app/mcp/tools/base_tool"
Dir[Rails.root.join("app/mcp/tools/*.rb")].each { |f| require f }
require_relative "../../app/mcp/resources/base_resource"
Dir[Rails.root.join("app/mcp/resources/*.rb")].each { |f| require f }
require_relative "../../app/mcp/constitution_mcp_server"

RSpec.describe ConstitutionMcpServer do
  let(:server) { ConstitutionMcpServer.new }

  describe "initialize response" do
    it "returns server info and capabilities" do
      response = server.send(:handle_request, { "method" => "initialize", "id" => 1 })
      expect(response[:result][:serverInfo][:name]).to eq("constitution")
      expect(response[:result][:capabilities][:tools]).to be_present
    end
  end

  describe "tools/list" do
    it "returns all 8 tools" do
      response = server.send(:handle_request, { "method" => "tools/list", "id" => 2 })
      tool_names = response[:result][:tools].map { |t| t[:name] }
      expect(tool_names).to include("constitution.list_work_orders")
      expect(tool_names).to include("constitution.search")
      expect(tool_names.length).to eq(8)
    end
  end

  describe "resources/list" do
    it "returns all 4 resources" do
      response = server.send(:handle_request, { "method" => "resources/list", "id" => 3 })
      expect(response[:result][:resources].length).to eq(4)
    end
  end

  describe "unknown method" do
    it "returns error" do
      response = server.send(:handle_request, { "method" => "unknown", "id" => 4 })
      expect(response[:error][:code]).to eq(-32601)
    end
  end
end
