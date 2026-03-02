require "rails_helper"

RSpec.describe Importers::GitImporter do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }

  describe "#import!" do
    before do
      allow(GraphService).to receive(:create_node)
      allow(Open3).to receive(:capture2)
        .with("git", "ls-remote", "--symref", anything, "HEAD")
        .and_return([ "ref: refs/heads/main\tHEAD\n", double(success?: true) ])
    end

    it "creates a repository and triggers indexing" do
      allow(CodebaseIndexJob).to receive(:perform_later)

      importer = Importers::GitImporter.new(
        project: project,
        user: user,
        url: "https://github.com/example/my-app.git"
      )

      repository = importer.import!

      expect(repository).to be_persisted
      expect(repository.name).to eq("my-app")
      expect(repository.url).to eq("https://github.com/example/my-app.git")
      expect(CodebaseIndexJob).to have_received(:perform_later).with(repository.id, project_id: project.id, user_id: user.id)
    end

    it "creates a service system if none provided" do
      allow(CodebaseIndexJob).to receive(:perform_later)

      expect {
        Importers::GitImporter.new(
          project: project,
          user: user,
          url: "https://github.com/example/new-service.git"
        )
      }.to change(ServiceSystem, :count).by(1)
    end

    it "uses provided service system" do
      allow(CodebaseIndexJob).to receive(:perform_later)
      service_system = create(:service_system, team: team)

      importer = Importers::GitImporter.new(
        project: project,
        user: user,
        url: "https://github.com/example/app.git",
        service_system: service_system
      )

      repository = importer.import!
      expect(repository.service_system).to eq(service_system)
    end

    it "detects github provider from URL" do
      allow(CodebaseIndexJob).to receive(:perform_later)

      importer = Importers::GitImporter.new(
        project: project,
        user: user,
        url: "https://github.com/example/my-app.git"
      )

      repository = importer.import!
      expect(repository.provider).to eq("github")
    end

    it "detects gitlab provider from URL" do
      allow(CodebaseIndexJob).to receive(:perform_later)

      importer = Importers::GitImporter.new(
        project: project,
        user: user,
        url: "https://gitlab.com/example/my-app.git"
      )

      repository = importer.import!
      expect(repository.provider).to eq("gitlab")
    end

    it "sets unknown provider for other URLs" do
      allow(CodebaseIndexJob).to receive(:perform_later)

      importer = Importers::GitImporter.new(
        project: project,
        user: user,
        url: "https://bitbucket.org/example/my-app.git"
      )

      repository = importer.import!
      expect(repository.provider).to eq("unknown")
    end

    it "detects default branch via git ls-remote" do
      allow(CodebaseIndexJob).to receive(:perform_later)
      allow(Open3).to receive(:capture2)
        .with("git", "ls-remote", "--symref", anything, "HEAD")
        .and_return([ "ref: refs/heads/master\tHEAD\n", double(success?: true) ])

      importer = Importers::GitImporter.new(
        project: project,
        user: user,
        url: "https://github.com/example/legacy-app.git"
      )

      repository = importer.import!
      expect(repository.default_branch).to eq("master")
    end

    it "falls back to main when ls-remote fails" do
      allow(CodebaseIndexJob).to receive(:perform_later)
      allow(Open3).to receive(:capture2)
        .with("git", "ls-remote", "--symref", anything, "HEAD")
        .and_return([ "", double(success?: false) ])

      importer = Importers::GitImporter.new(
        project: project,
        user: user,
        url: "https://github.com/example/fallback-app.git"
      )

      repository = importer.import!
      expect(repository.default_branch).to eq("main")
    end
  end
end
