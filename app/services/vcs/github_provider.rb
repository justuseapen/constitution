module Vcs
  class GithubProvider < BaseProvider
    def create_merge_request(branch:, title:, body:)
      output, status = Open3.capture2e(
        "gh", "pr", "create",
        "--title", title,
        "--body", body,
        "--head", branch,
        chdir: repo_path
      )

      if status.success?
        output.strip.lines.last.strip
      else
        Rails.logger.warn("Failed to create GitHub PR: #{output}")
        nil
      end
    end

    def diff(pr_identifier:)
      output, status = Open3.capture2e(
        "gh", "pr", "diff", pr_identifier.to_s,
        chdir: repo_path
      )
      status.success? ? output : nil
    end

    def post_review(pr_identifier:, body:, comments: [])
      args = [ "gh", "pr", "review", pr_identifier.to_s, "--comment", "--body", body ]
      _output, status = Open3.capture2e(*args, chdir: repo_path)
      status.success?
    end

    def pr_status(pr_identifier:)
      output, status = Open3.capture2e(
        "gh", "pr", "view", pr_identifier.to_s, "--json", "state,reviewDecision",
        chdir: repo_path
      )
      return nil unless status.success?

      data = JSON.parse(output)
      normalize_status(data["state"], data["reviewDecision"])
    rescue JSON::ParserError
      nil
    end

    def merge_request_term
      "Pull Request"
    end

    def cli_tool
      "gh"
    end

    private

    def normalize_status(state, review_decision)
      case state
      when "MERGED" then :merged
      when "CLOSED" then :closed
      else
        case review_decision
        when "APPROVED" then :approved
        when "CHANGES_REQUESTED" then :changes_requested
        else :open
        end
      end
    end
  end
end
