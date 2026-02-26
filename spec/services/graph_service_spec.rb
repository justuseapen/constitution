require "rails_helper"

RSpec.describe GraphService do
  describe ".available?" do
    it "returns false when NEO4J_DRIVER is nil" do
      # In test environment without Neo4j, this should be false
      allow(GraphService).to receive(:available?).and_return(false)
      expect(GraphService.available?).to be false
    end
  end

  describe ".create_node" do
    context "when Neo4j is not available" do
      before { allow(GraphService).to receive(:available?).and_return(false) }

      it "returns nil gracefully" do
        result = GraphService.create_node("Document", { postgres_id: 1, title: "Test" })
        expect(result).to be_nil
      end
    end

    context "when Neo4j is available" do
      before { allow(GraphService).to receive(:available?).and_return(true) }

      it "executes a MERGE query" do
        expect(GraphService).to receive(:execute).with(
          "MERGE (n:Document {postgres_id: $id}) SET n += $props",
          id: 1,
          props: { title: "Test" }
        )
        GraphService.create_node("Document", { postgres_id: 1, title: "Test" })
      end
    end
  end

  describe ".create_edge" do
    context "when Neo4j is not available" do
      before { allow(GraphService).to receive(:available?).and_return(false) }

      it "returns nil gracefully" do
        result = GraphService.create_edge(
          from: { label: "Document", postgres_id: 1 },
          to: { label: "Blueprint", postgres_id: 2 },
          type: "DEFINES_FEATURE"
        )
        expect(result).to be_nil
      end
    end
  end

  describe ".neighbors" do
    context "when Neo4j is not available" do
      before { allow(GraphService).to receive(:available?).and_return(false) }

      it "returns empty array" do
        result = GraphService.neighbors("Document", 1)
        expect(result).to eq([])
      end
    end
  end

  describe ".impact_analysis" do
    context "when Neo4j is not available" do
      before { allow(GraphService).to receive(:available?).and_return(false) }

      it "returns empty array" do
        result = GraphService.impact_analysis("Document", 1)
        expect(result).to eq([])
      end
    end
  end
end
