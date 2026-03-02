require "rails_helper"

RSpec.describe MermaidGenerator do
  let(:team) { create(:team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system) }
  let(:generator) { described_class.new }

  describe "#dependency_flowchart" do
    it "returns empty state when no artifacts" do
      result = generator.dependency_flowchart(repository)
      expect(result).to include("No artifacts found")
    end

    it "groups artifacts by type in subgraphs" do
      file = create(:codebase_file, repository: repository, path: "app/models/user.rb", content: "class User; end")
      create(:extracted_artifact, codebase_file: file, artifact_type: :model, name: "User")

      file2 = create(:codebase_file, repository: repository, path: "app/controllers/users_controller.rb", content: "class UsersController; end")
      create(:extracted_artifact, codebase_file: file2, artifact_type: :controller, name: "UsersController")

      result = generator.dependency_flowchart(repository)
      expect(result).to include("flowchart TD")
      expect(result).to include("subgraph Models")
      expect(result).to include("subgraph Controllers")
      expect(result).to include("User")
      expect(result).to include("UsersController")
    end

    it "infers edges from code content references" do
      file1 = create(:codebase_file, repository: repository, path: "app/controllers/users_controller.rb",
        content: "class UsersController\n  def show\n    @user = User.find(params[:id])\n  end\nend")
      ctrl = create(:extracted_artifact, codebase_file: file1, artifact_type: :controller, name: "UsersController")

      file2 = create(:codebase_file, repository: repository, path: "app/models/user.rb", content: "class User < ApplicationRecord; end")
      model = create(:extracted_artifact, codebase_file: file2, artifact_type: :model, name: "User")

      result = generator.dependency_flowchart(repository)
      expect(result).to include("-->")
    end
  end

  describe "#model_class_diagram" do
    it "returns empty state when no models" do
      result = generator.model_class_diagram(repository)
      expect(result).to include("No models found")
    end

    it "generates classDiagram for model artifacts" do
      file = create(:codebase_file, repository: repository, path: "app/models/user.rb", content: "class User; end")
      create(:extracted_artifact, codebase_file: file, artifact_type: :model, name: "User")

      result = generator.model_class_diagram(repository)
      expect(result).to include("classDiagram")
      expect(result).to include("class User")
    end
  end
end
