require "rails_helper"

RSpec.describe Repository, type: :model do
  it { should belong_to(:service_system) }
  it { should have_many(:codebase_files).dependent(:destroy) }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:url) }
  it { should define_enum_for(:indexing_status).with_values(pending: 0, indexing: 1, indexed: 2, failed: 3) }

  describe "URL validation" do
    let(:service_system) { create(:service_system) }

    it "accepts HTTPS URLs" do
      repo = build(:repository, url: "https://github.com/owner/repo.git", service_system: service_system)
      expect(repo).to be_valid
    end

    it "accepts HTTPS URLs without .git suffix" do
      repo = build(:repository, url: "https://github.com/owner/repo", service_system: service_system)
      expect(repo).to be_valid
    end

    it "accepts SSH URLs" do
      repo = build(:repository, url: "git@github.com:owner/repo.git", service_system: service_system)
      expect(repo).to be_valid
    end

    it "accepts SSH URLs without .git suffix" do
      repo = build(:repository, url: "git@gitlab.com:owner/repo", service_system: service_system)
      expect(repo).to be_valid
    end

    it "accepts explicit SSH URLs" do
      repo = build(:repository, url: "ssh://git@gitlab.com/owner/repo.git", service_system: service_system)
      expect(repo).to be_valid
    end

    it "rejects invalid URLs" do
      repo = build(:repository, url: "not-a-url", service_system: service_system)
      expect(repo).not_to be_valid
      expect(repo.errors[:url]).to include("must be a valid git URL (HTTPS or SSH)")
    end

    it "rejects FTP URLs" do
      repo = build(:repository, url: "ftp://example.com/repo.git", service_system: service_system)
      expect(repo).not_to be_valid
    end

    it "prevents duplicate URLs within the same service system" do
      create(:repository, url: "https://github.com/owner/repo.git", service_system: service_system)
      dup = build(:repository, url: "https://github.com/owner/repo.git", service_system: service_system)
      expect(dup).not_to be_valid
      expect(dup.errors[:url]).to include("has already been imported")
    end
  end
end
