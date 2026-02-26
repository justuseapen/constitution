require "rails_helper"

RSpec.describe GraphSync do
  describe "after commit callbacks" do
    before do
      allow(GraphService).to receive(:create_node)
      allow(GraphService).to receive(:delete_node)
    end

    it "syncs to graph on create" do
      document = create(:document)
      expect(GraphService).to have_received(:create_node).with("Document", hash_including(postgres_id: document.id))
    end

    it "syncs to graph on update" do
      document = create(:document)
      document.update!(title: "Updated Title")
      expect(GraphService).to have_received(:create_node).with("Document", hash_including(postgres_id: document.id)).at_least(:twice)
    end

    it "removes from graph on destroy" do
      document = create(:document)
      doc_id = document.id
      document.destroy
      expect(GraphService).to have_received(:delete_node).with("Document", doc_id)
    end
  end

  describe "#graph_properties" do
    it "includes postgres_id and title" do
      document = build(:document, title: "Test Doc")
      document.id = 42
      props = document.graph_properties
      expect(props[:postgres_id]).to eq(42)
      expect(props[:title]).to eq("Test Doc")
    end
  end
end
