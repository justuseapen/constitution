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
end
