module Vcs
  class ProviderFactory
    def self.for(repository)
      case repository.provider
      when "github"
        GithubProvider.new(repository: repository)
      when "gitlab"
        GitlabProvider.new(repository: repository)
      else
        raise "Unsupported VCS provider '#{repository.provider}' for repository '#{repository.name}'. " \
              "Only GitHub and GitLab repositories support PR/MR creation."
      end
    end
  end
end
