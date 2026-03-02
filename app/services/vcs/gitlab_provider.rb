module Vcs
  class GitlabProvider < BaseProvider
    def create_merge_request(branch:, title:, body:)
      validate_environment!

      output, status = Open3.capture2e(
        { "GITLAB_TOKEN" => gitlab_token },
        "glab", "mr", "create",
        "--title", title,
        "--description", body,
        "--source-branch", branch,
        "--target-branch", repository.default_branch,
        "--yes",
        chdir: repo_path
      )

      if status.success?
        output.strip.lines.last.strip
      else
        Rails.logger.warn("Failed to create GitLab MR: #{output}")
        nil
      end
    end

    def diff(pr_identifier:)
      output, status = Open3.capture2e(
        { "GITLAB_TOKEN" => gitlab_token },
        "glab", "mr", "diff", pr_identifier.to_s,
        chdir: repo_path
      )
      status.success? ? output : nil
    end

    def post_review(pr_identifier:, body:, comments: [])
      _output, status = Open3.capture2e(
        { "GITLAB_TOKEN" => gitlab_token },
        "glab", "mr", "note", pr_identifier.to_s, "--message", body,
        chdir: repo_path
      )
      status.success?
    end

    def pr_status(pr_identifier:)
      output, status = Open3.capture2e(
        { "GITLAB_TOKEN" => gitlab_token },
        "glab", "mr", "view", pr_identifier.to_s, "--output", "json",
        chdir: repo_path
      )
      return nil unless status.success?

      data = JSON.parse(output)
      normalize_status(data["state"])
    rescue JSON::ParserError
      nil
    end

    def merge_request_term
      "Merge Request"
    end

    def cli_tool
      "glab"
    end

    private

    def gitlab_token
      ENV["GITLAB_TOKEN"]
    end

    def validate_environment!
      unless system("which glab > /dev/null 2>&1")
        raise "glab CLI not found in PATH. Install it: https://gitlab.com/gitlab-org/cli"
      end

      if gitlab_token.blank?
        raise "GITLAB_TOKEN environment variable is not set. Set it to authenticate with GitLab."
      end
    end

    def normalize_status(state)
      case state
      when "merged" then :merged
      when "closed" then :closed
      else :open
      end
    end
  end
end
