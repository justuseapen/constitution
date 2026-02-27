require "rails_helper"

RSpec.describe Importers::GitImporter do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }

  describe "#import!" do
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
      expect(CodebaseIndexJob).to have_received(:perform_later).with(repository.id)
    end

    it "creates a service system if none provided" do
      allow(CodebaseIndexJob).to receive(:perform_later)

      importer = Importers::GitImporter.new(
        project: project,
        user: user,
        url: "https://github.com/example/new-service.git"
      )

      expect { importer.import! }.to change(ServiceSystem, :count).by(1)
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
  end
end
