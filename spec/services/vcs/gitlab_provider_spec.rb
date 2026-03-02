require "rails_helper"

RSpec.describe Vcs::GitlabProvider do
  let(:service_system) { create(:service_system) }
  let(:repository) { create(:repository, provider: :gitlab, service_system: service_system, default_branch: "main") }
  let(:provider) { described_class.new(repository: repository) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GITLAB_TOKEN").and_return("glpat-test-token")
  end

  describe "#create_merge_request" do
    before do
      allow_any_instance_of(described_class).to receive(:system).with("which glab > /dev/null 2>&1").and_return(true)
    end

    it "creates an MR via glab CLI" do
      allow(Open3).to receive(:capture2e).and_return(
        ["https://gitlab.com/owner/repo/-/merge_requests/42\n", double(success?: true)]
      )

      url = provider.create_merge_request(
        branch: "feat/test",
        title: "Test MR",
        body: "Description"
      )

      expect(url).to eq("https://gitlab.com/owner/repo/-/merge_requests/42")
      expect(Open3).to have_received(:capture2e).with(
        { "GITLAB_TOKEN" => "glpat-test-token" },
        "glab", "mr", "create",
        "--title", "Test MR",
        "--description", "Description",
        "--source-branch", "feat/test",
        "--target-branch", "main",
        "--yes",
        chdir: anything
      )
    end

    it "returns nil on failure" do
      allow(Open3).to receive(:capture2e).and_return(
        ["error message", double(success?: false)]
      )

      url = provider.create_merge_request(branch: "feat/test", title: "Test", body: "Body")
      expect(url).to be_nil
    end

    it "raises when glab is not installed" do
      allow_any_instance_of(described_class).to receive(:system).with("which glab > /dev/null 2>&1").and_return(false)

      expect {
        provider.create_merge_request(branch: "feat/test", title: "Test", body: "Body")
      }.to raise_error(/glab CLI not found/)
    end

    it "raises when GITLAB_TOKEN is not set" do
      allow(ENV).to receive(:[]).with("GITLAB_TOKEN").and_return(nil)

      expect {
        provider.create_merge_request(branch: "feat/test", title: "Test", body: "Body")
      }.to raise_error(/GITLAB_TOKEN/)
    end
  end

  describe "#pr_status" do
    it "returns :open for open MRs" do
      json = '{"state":"opened"}'
      allow(Open3).to receive(:capture2e).and_return([json, double(success?: true)])

      expect(provider.pr_status(pr_identifier: "42")).to eq(:open)
    end

    it "returns :merged for merged MRs" do
      json = '{"state":"merged"}'
      allow(Open3).to receive(:capture2e).and_return([json, double(success?: true)])

      expect(provider.pr_status(pr_identifier: "42")).to eq(:merged)
    end

    it "returns :closed for closed MRs" do
      json = '{"state":"closed"}'
      allow(Open3).to receive(:capture2e).and_return([json, double(success?: true)])

      expect(provider.pr_status(pr_identifier: "42")).to eq(:closed)
    end
  end

  describe "#merge_request_term" do
    it "returns Merge Request" do
      expect(provider.merge_request_term).to eq("Merge Request")
    end
  end

  describe "#cli_tool" do
    it "returns glab" do
      expect(provider.cli_tool).to eq("glab")
    end
  end
end
