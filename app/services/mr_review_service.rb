class MrReviewService
  def initialize(execution:)
    @execution = execution
    @work_order = execution.work_order
    @repository = execution.repository
  end

  def review!
    provider = Vcs::ProviderFactory.for(@repository)
    pr_identifier = extract_pr_identifier(@execution.pull_request_url)
    return nil unless pr_identifier

    diff = provider.diff(pr_identifier: pr_identifier)
    return nil unless diff.present?

    static_findings = run_static_checks(diff)
    ai_findings = run_ai_review(diff)

    review_body = format_review(static_findings, ai_findings)
    provider.post_review(pr_identifier: pr_identifier, body: review_body)

    create_feedback_item(static_findings, ai_findings)

    { static: static_findings, ai: ai_findings }
  end

  private

  def extract_pr_identifier(url)
    return nil unless url.present?

    # GitHub: https://github.com/owner/repo/pull/42 -> "42"
    # GitLab: https://gitlab.com/owner/repo/-/merge_requests/42 -> "42"
    url.split("/").last
  end

  def run_static_checks(diff)
    findings = []
    lines = diff.lines

    total_changes = lines.count { |l| l.start_with?("+") || l.start_with?("-") }
    if total_changes > 500
      findings << { severity: "warning", message: "Large diff: #{total_changes} changed lines. Consider splitting into smaller PRs." }
    end

    changed_source_files = extract_changed_files(diff).select { |f| source_file?(f) }
    changed_test_files = extract_changed_files(diff).select { |f| test_file?(f) }

    missing_tests = changed_source_files.reject do |src|
      changed_test_files.any? { |t| test_covers?(t, src) }
    end

    if missing_tests.any?
      findings << { severity: "info", message: "Source files without corresponding test changes: #{missing_tests.join(', ')}" }
    end

    findings
  end

  def run_ai_review(diff)
    prompt = build_review_prompt(diff)

    response = OPENROUTER_CLIENT.chat(
      parameters: {
        model: "anthropic/claude-sonnet-4-5",
        messages: [ { role: "user", content: prompt } ],
        max_tokens: 2000
      }
    )

    content = response.dig("choices", 0, "message", "content")
    parse_ai_response(content)
  rescue StandardError => e
    Rails.logger.warn("AI review failed: #{e.message}")
    { overall: "error", summary: "AI review failed: #{e.message}", criteria_met: [], issues: [] }
  end

  def build_review_prompt(diff)
    <<~PROMPT
      Review this code change against the acceptance criteria below.

      ## Acceptance Criteria
      #{@work_order.acceptance_criteria}

      ## Diff (truncated to 4000 chars)
      #{diff.truncate(4000)}

      Check for:
      1. Does the implementation satisfy each acceptance criterion?
      2. Are there security issues (injection, auth bypass, data exposure)?
      3. Are there obvious performance problems?
      4. Are tests included for the changes?

      Return your findings as JSON (no markdown fences):
      {
        "overall": "approve" or "request_changes",
        "summary": "brief summary",
        "criteria_met": [{"criterion": "...", "met": true/false, "comment": "..."}],
        "issues": [{"severity": "error" or "warning" or "info", "file": "...", "line": 0, "message": "..."}]
      }
    PROMPT
  end

  def parse_ai_response(content)
    json_match = content&.match(/\{[\s\S]*\}/)
    return { overall: "error", summary: "Could not parse AI response", criteria_met: [], issues: [] } unless json_match

    JSON.parse(json_match[0], symbolize_names: true)
  rescue JSON::ParserError
    { overall: "error", summary: "Could not parse AI response", criteria_met: [], issues: [] }
  end

  def format_review(static_findings, ai_findings)
    parts = [ "## Constitution QA Review\n" ]

    if ai_findings[:summary].present?
      parts << "**Summary:** #{ai_findings[:summary]}\n"
      parts << "**Verdict:** #{ai_findings[:overall]&.upcase}\n"
    end

    if ai_findings[:criteria_met]&.any?
      parts << "\n### Acceptance Criteria\n"
      ai_findings[:criteria_met].each do |c|
        status = c[:met] ? "PASS" : "FAIL"
        parts << "- [#{status}] #{c[:criterion]}: #{c[:comment]}"
      end
    end

    if static_findings.any? || ai_findings[:issues]&.any?
      parts << "\n### Issues Found\n"
      (static_findings + (ai_findings[:issues] || [])).each do |issue|
        sev = issue[:severity] || issue["severity"]
        msg = issue[:message] || issue["message"]
        parts << "- **#{sev&.upcase}**: #{msg}"
      end
    end

    parts.join("\n")
  end

  def create_feedback_item(static_findings, ai_findings)
    summary = ai_findings[:summary] || "QA review for work order '#{@work_order.title}'"
    all_issues = static_findings + (ai_findings[:issues] || [])

    FeedbackItem.create!(
      project: @work_order.project,
      title: "QA Review: #{@work_order.title}",
      body: format_review(static_findings, ai_findings),
      source: "qa_pipeline",
      category: all_issues.any? { |i| (i[:severity] || i["severity"]) == "error" } ? :bug : :uncategorized,
      technical_context: {
        work_order_id: @work_order.id,
        execution_id: @execution.id,
        pr_url: @execution.pull_request_url,
        overall: ai_findings[:overall],
        issue_count: all_issues.size
      }
    )
  end

  def extract_changed_files(diff)
    diff.scan(%r{^diff --git a/(.+?) b/}).flatten.uniq
  end

  def source_file?(path)
    path.match?(/\.(rb|js|ts|py|go|java|rs)$/) && !test_file?(path)
  end

  def test_file?(path)
    path.match?(%r{(spec|test|__tests__|_test\.)/}) || path.match?(/_spec\.(rb|js|ts)$/) || path.match?(/_test\.(go|py|rs)$/)
  end

  def test_covers?(test_path, source_path)
    source_name = File.basename(source_path, ".*")
    test_path.include?(source_name)
  end
end
