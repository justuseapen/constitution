require "rails_helper"

RSpec.describe Vcs::GithubProvider do
  let(:service_system) { create(:service_system) }
  let(:repository) { create(:repository, provider: :github, service_system: service_system) }
  let(:provider) { described_class.new(repository: repository) }

  describe "#create_merge_request" do
    it "creates a PR via gh CLI" do
      allow(Open3).to receive(:capture2e).and_return(
        ["https://github.com/owner/repo/pull/42\n", double(success?: true)]
      )

      url = provider.create_merge_request(
        branch: "feat/test",
        title: "Test PR",
        body: "Description"
      )

      expect(url).to eq("https://github.com/owner/repo/pull/42")
      expect(Open3).to have_received(:capture2e).with(
        "gh", "pr", "create",
        "--title", "Test PR",
        "--body", "Description",
        "--head", "feat/test",
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
  end

  describe "#diff" do
    it "fetches PR diff via gh CLI" do
      allow(Open3).to receive(:capture2e).and_return(
        ["diff content here", double(success?: true)]
      )

      result = provider.diff(pr_identifier: "42")
      expect(result).to eq("diff content here")
    end
  end

  describe "#pr_status" do
    it "returns :open for open PRs" do
      json = '{"state":"OPEN","reviewDecision":""}'
      allow(Open3).to receive(:capture2e).and_return([json, double(success?: true)])

      expect(provider.pr_status(pr_identifier: "42")).to eq(:open)
    end

    it "returns :merged for merged PRs" do
      json = '{"state":"MERGED","reviewDecision":""}'
      allow(Open3).to receive(:capture2e).and_return([json, double(success?: true)])

      expect(provider.pr_status(pr_identifier: "42")).to eq(:merged)
    end

    it "returns :approved when review approved" do
      json = '{"state":"OPEN","reviewDecision":"APPROVED"}'
      allow(Open3).to receive(:capture2e).and_return([json, double(success?: true)])

      expect(provider.pr_status(pr_identifier: "42")).to eq(:approved)
    end

    it "returns :changes_requested when changes requested" do
      json = '{"state":"OPEN","reviewDecision":"CHANGES_REQUESTED"}'
      allow(Open3).to receive(:capture2e).and_return([json, double(success?: true)])

      expect(provider.pr_status(pr_identifier: "42")).to eq(:changes_requested)
    end
  end

  describe "#merge_request_term" do
    it "returns Pull Request" do
      expect(provider.merge_request_term).to eq("Pull Request")
    end
  end

  describe "#cli_tool" do
    it "returns gh" do
      expect(provider.cli_tool).to eq("gh")
    end
  end
end
