require "rails_helper"

RSpec.describe Vcs::ProviderFactory do
  describe ".for" do
    let(:service_system) { create(:service_system) }

    it "returns GithubProvider for github repositories" do
      repo = create(:repository, provider: :github, service_system: service_system)
      provider = described_class.for(repo)
      expect(provider).to be_a(Vcs::GithubProvider)
    end

    it "returns GitlabProvider for gitlab repositories" do
      repo = create(:repository, provider: :gitlab, service_system: service_system)
      provider = described_class.for(repo)
      expect(provider).to be_a(Vcs::GitlabProvider)
    end

    it "raises for unknown provider" do
      repo = create(:repository, provider: :unknown, service_system: service_system)
      expect { described_class.for(repo) }.to raise_error(RuntimeError, /Unsupported VCS provider/)
    end
  end
end
