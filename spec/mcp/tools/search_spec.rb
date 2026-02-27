require "rails_helper"
require_relative "../../../app/mcp/tools/base_tool"
require_relative "../../../app/mcp/tools/search"

RSpec.describe Tools::Search do
  let(:tool) { Tools::Search.new }

  describe "#definition" do
    it "returns proper MCP tool definition" do
      defn = tool.definition
      expect(defn[:name]).to eq("constitution.search")
      expect(defn[:inputSchema][:properties]).to have_key(:query)
    end
  end
end
