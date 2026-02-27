require "rails_helper"

RSpec.describe Importers::DocumentImporter do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }

  describe "#import!" do
    it "imports markdown files as HTML" do
      file = double("UploadedFile",
        original_filename: "requirements.md",
        content_type: "text/markdown",
        read: "# Requirements\n\n## Auth\n\nUsers must log in.",
        tempfile: nil,
        path: nil
      )
      allow(file).to receive(:respond_to?).with(:original_filename).and_return(true)
      allow(file).to receive(:respond_to?).with(:content_type).and_return(true)
      allow(file).to receive(:respond_to?).with(:read).and_return(true)
      allow(file).to receive(:respond_to?).with(:tempfile).and_return(false)

      importer = Importers::DocumentImporter.new(
        project: project,
        user: user,
        file: file
      )

      document = importer.import!

      expect(document).to be_persisted
      expect(document.title).to eq("Requirements")
      expect(document.body).to include("Requirements")
      expect(document.body).to include("Auth")
    end

    it "imports plain text files" do
      file = double("UploadedFile",
        original_filename: "notes.txt",
        content_type: "text/plain",
        read: "These are some notes.\n\nSecond paragraph.",
        tempfile: nil,
        path: nil
      )
      allow(file).to receive(:respond_to?).with(:original_filename).and_return(true)
      allow(file).to receive(:respond_to?).with(:content_type).and_return(true)
      allow(file).to receive(:respond_to?).with(:read).and_return(true)
      allow(file).to receive(:respond_to?).with(:tempfile).and_return(false)

      importer = Importers::DocumentImporter.new(
        project: project,
        user: user,
        file: file
      )

      document = importer.import!
      expect(document).to be_persisted
      expect(document.body).to include("notes")
    end
  end
end
