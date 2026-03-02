require "rails_helper"

RSpec.describe ContextBuilder do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }
  let(:document) { create(:document, project: project, created_by: user) }

  it "builds context with the current document" do
    context = ContextBuilder.new(project)
      .add_document(document)
      .build

    expect(context).to include(document.title)
    expect(context).to include(document.body)
  end

  it "respects token limits by truncating lower-priority sections" do
    context = ContextBuilder.new(project, max_tokens: 100)
      .add_document(document)
      .build

    expect(context.length).to be <= 400
  end

  it "returns empty string when no sections added" do
    context = ContextBuilder.new(project).build
    expect(context).to eq("")
  end

  it "supports method chaining" do
    builder = ContextBuilder.new(project)
    expect(builder.add_document(document)).to eq(builder)
  end

  describe "#add_semantic_code_search" do
    it "adds code chunks from semantic search results" do
      chunk = double("CodebaseChunk",
        content: "def authenticate\n  # auth logic\nend",
        start_line: 10,
        end_line: 12,
        codebase_file: double("CodebaseFile", path: "app/services/auth.rb")
      )

      allow(CodeSearchService).to receive(:search).and_return([ chunk ])

      context = ContextBuilder.new(project)
        .add_semantic_code_search("authentication")
        .build

      expect(context).to include("auth.rb")
      expect(context).to include("authenticate")
    end

    it "handles empty search results gracefully" do
      allow(CodeSearchService).to receive(:search).and_return([])

      context = ContextBuilder.new(project)
        .add_semantic_code_search("nonexistent feature")
        .build

      expect(context).to eq("")
    end
  end
end
