require "rails_helper"

RSpec.describe WorkOrderPromptBuilder do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, indexing_status: :indexed) }
  let(:work_order) { create(:work_order, project: project, title: "Add login page", description: "Build a login page with email and password") }

  describe "#build" do
    it "includes work order title and description" do
      builder = described_class.new(work_order: work_order, repository: repository)
      prompt = builder.build

      expect(prompt).to include("Add login page")
      expect(prompt).to include("Build a login page with email and password")
    end

    it "includes acceptance criteria when present" do
      builder = described_class.new(work_order: work_order, repository: repository)
      prompt = builder.build

      expect(prompt).to include("Criterion 1")
    end

    it "includes branch naming instruction with work order id" do
      builder = described_class.new(work_order: work_order, repository: repository)
      prompt = builder.build

      expect(prompt).to include("wo-#{work_order.id}")
    end

    it "includes completion signals" do
      builder = described_class.new(work_order: work_order, repository: repository)
      prompt = builder.build

      expect(prompt).to include("<constitution>COMPLETE</constitution>")
      expect(prompt).to include("<constitution>FAILED:")
    end

    it "includes extracted artifacts when available" do
      file = create(:codebase_file, repository: repository, path: "app/models/user.rb", content: "class User; end")
      create(:extracted_artifact, codebase_file: file, artifact_type: :model, name: "User")

      builder = described_class.new(work_order: work_order, repository: repository)
      prompt = builder.build

      expect(prompt).to include("User")
    end
  end

  describe "#select_repository" do
    it "returns the only repo when project has one" do
      result = described_class.new(work_order: work_order, repository: nil).select_repository([repository])
      expect(result).to eq(repository)
    end

    it "scores repos by artifact overlap with work order text" do
      repo_a = create(:repository, service_system: service_system, name: "repo-a", indexing_status: :indexed)
      repo_b = create(:repository, service_system: service_system, name: "repo-b", indexing_status: :indexed)

      file_a = create(:codebase_file, repository: repo_a, path: "app/models/login.rb")
      create(:extracted_artifact, codebase_file: file_a, artifact_type: :model, name: "Login")

      file_b = create(:codebase_file, repository: repo_b, path: "app/models/invoice.rb")
      create(:extracted_artifact, codebase_file: file_b, artifact_type: :model, name: "Invoice")

      result = described_class.new(work_order: work_order, repository: nil).select_repository([repo_a, repo_b])
      expect(result).to eq(repo_a)
    end
  end
end
