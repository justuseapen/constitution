require "rails_helper"

RSpec.describe AiDiagramGenerator do
  let(:team) { create(:team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system) }
  let(:generator) { described_class.new }

  describe "#sequence_diagram_for_route" do
    let(:file) { create(:codebase_file, repository: repository, path: "config/routes.rb", content: "get '/users' => 'users#index'") }
    let(:artifact) { create(:extracted_artifact, codebase_file: file, artifact_type: :route, name: "GET /users") }

    it "generates a sequence diagram via AI" do
      allow(OPENROUTER_CLIENT).to receive(:chat).and_return({
        "choices" => [{
          "message" => { "content" => "sequenceDiagram\n    Client->>Controller: GET /users\n    Controller->>Model: User.all" }
        }]
      })

      result = generator.sequence_diagram_for_route(artifact)
      expect(result).to include("sequenceDiagram")
    end

    it "strips markdown fences from response" do
      allow(OPENROUTER_CLIENT).to receive(:chat).and_return({
        "choices" => [{
          "message" => { "content" => "```mermaid\nsequenceDiagram\n    A->>B: call\n```" }
        }]
      })

      result = generator.sequence_diagram_for_route(artifact)
      expect(result).to start_with("sequenceDiagram")
      expect(result).not_to include("```")
    end

    it "returns nil on API failure" do
      allow(OPENROUTER_CLIENT).to receive(:chat).and_raise(StandardError, "API down")

      result = generator.sequence_diagram_for_route(artifact)
      expect(result).to be_nil
    end
  end
end
