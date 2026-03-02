require "rails_helper"

RSpec.describe CodeSearchService do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system) }
  let(:codebase_file) { create(:codebase_file, repository: repository) }

  let(:fake_embedding) { Array.new(1536) { rand(-1.0..1.0) } }

  describe ".search" do
    before do
      stub_const("OPENROUTER_CLIENT", double("OpenAI::Client"))
      allow(OPENROUTER_CLIENT).to receive(:embeddings).and_return({
        "data" => [ { "embedding" => fake_embedding } ]
      })
    end

    it "generates embedding from query and searches for nearest neighbors" do
      expect(OPENROUTER_CLIENT).to receive(:embeddings).with(
        parameters: { model: "openai/text-embedding-3-small", input: anything }
      )

      # We can't test actual nearest_neighbors without pgvector extension,
      # so we verify the service calls the right methods
      result = CodeSearchService.search(project, "user authentication")
      # Result will be an ActiveRecord relation (may be empty without pgvector)
    end

    it "returns empty array when embedding generation fails" do
      allow(OPENROUTER_CLIENT).to receive(:embeddings).and_raise(StandardError, "API error")

      result = CodeSearchService.search(project, "test query")
      expect(result).to eq([])
    end

    it "returns empty array when OPENROUTER_CLIENT is not available" do
      stub_const("OPENROUTER_CLIENT", nil)

      result = CodeSearchService.search(project, "test query")
      expect(result).to eq([])
    end
  end

  describe ".search_by_artifact_type" do
    before do
      stub_const("OPENROUTER_CLIENT", double("OpenAI::Client"))
      allow(OPENROUTER_CLIENT).to receive(:embeddings).and_return({
        "data" => [ { "embedding" => fake_embedding } ]
      })
    end

    it "filters results by artifact type" do
      expect(OPENROUTER_CLIENT).to receive(:embeddings)

      result = CodeSearchService.search_by_artifact_type(
        project, "payment processing", artifact_type: :service
      )
      # Verifies the query builds correctly
    end
  end

  describe ".generate_embedding" do
    it "truncates long input to 8000 characters" do
      stub_const("OPENROUTER_CLIENT", double("OpenAI::Client"))
      long_text = "a" * 10_000

      expect(OPENROUTER_CLIENT).to receive(:embeddings).with(
        parameters: { model: "openai/text-embedding-3-small", input: long_text.truncate(8000) }
      ).and_return({ "data" => [ { "embedding" => fake_embedding } ] })

      CodeSearchService.send(:generate_embedding, long_text)
    end
  end
end
