require "open3"

module Vcs
  class BaseProvider
    def initialize(repository:)
      @repository = repository
      @repo_path = Rails.root.join("tmp", "repos", repository.id.to_s).to_s
    end

    def create_merge_request(branch:, title:, body:)
      raise NotImplementedError, "#{self.class}#create_merge_request must be implemented"
    end

    def diff(pr_identifier:)
      raise NotImplementedError, "#{self.class}#diff must be implemented"
    end

    def post_review(pr_identifier:, body:, comments: [])
      raise NotImplementedError, "#{self.class}#post_review must be implemented"
    end

    def pr_status(pr_identifier:)
      raise NotImplementedError, "#{self.class}#pr_status must be implemented"
    end

    def merge_request_term
      "Pull Request"
    end

    def cli_tool
      raise NotImplementedError, "#{self.class}#cli_tool must be implemented"
    end

    private

    attr_reader :repository, :repo_path
  end
end
