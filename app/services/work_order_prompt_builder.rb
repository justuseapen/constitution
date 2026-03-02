class WorkOrderPromptBuilder
  MAX_CONTEXT_TOKENS = 8000
  CHARS_PER_TOKEN = 4

  def initialize(work_order:, repository:, execution: nil, include_feedback: false)
    @work_order = work_order
    @repository = repository
    @execution = execution
    @include_feedback = include_feedback
  end

  def build
    sections = []
    sections << work_order_section
    sections << feedback_section if @include_feedback
    sections << artifacts_section if @repository
    sections << instructions_section
    sections.compact.join("\n\n")
  end

  def select_repository(repositories)
    return repositories.first if repositories.size <= 1

    text = "#{@work_order.title} #{@work_order.description}".downcase
    words = text.scan(/\w+/).to_set

    repositories.max_by do |repo|
      repo.codebase_files.includes(:extracted_artifacts).flat_map(&:extracted_artifacts).count do |artifact|
        artifact_words = artifact.name.underscore.scan(/\w+/)
        artifact_words.any? { |w| words.include?(w.downcase) }
      end
    end
  end

  def branch_name
    base = "wo-#{@work_order.id}-#{@work_order.title.parameterize[0..40]}"
    @execution ? "#{base}-e#{@execution.id}" : base
  end

  private

  def work_order_section
    section = "You are an autonomous coding agent. Implement the following work order.\n\n"
    section += "## Work Order\n"
    section += "**Title:** #{@work_order.title}\n\n"
    section += "**Description:** #{@work_order.description}\n\n" if @work_order.description.present?
    if @work_order.acceptance_criteria.present?
      section += "**Acceptance Criteria:**\n#{@work_order.acceptance_criteria}\n"
    end
    section
  end

  def feedback_section
    previous_execution = @work_order.executions
      .where(status: :completed)
      .where.not(pull_request_url: nil)
      .order(created_at: :desc)
      .first

    return nil unless previous_execution

    feedback_items = FeedbackItem.where(
      project: @work_order.project,
      source: "qa_pipeline"
    ).where("technical_context->>'execution_id' = ?", previous_execution.id.to_s)
      .order(created_at: :desc)
      .limit(1)

    return nil if feedback_items.empty?

    feedback = feedback_items.first
    <<~FEEDBACK
      ## Previous Attempt Feedback
      The previous implementation received the following review feedback:

      #{feedback.body}

      Address these issues in your implementation.
    FEEDBACK
  end

  def artifacts_section
    return nil unless @repository

    artifacts = @repository.codebase_files
      .joins(:extracted_artifacts)
      .includes(:extracted_artifacts)
      .limit(50)

    return nil if artifacts.empty?

    max_chars = MAX_CONTEXT_TOKENS * CHARS_PER_TOKEN
    section = "## Codebase Context\n\n"
    total = section.length

    artifacts.flat_map(&:extracted_artifacts).group_by(&:artifact_type).each do |type, items|
      type_header = "### #{type.humanize.pluralize}\n"
      break if total + type_header.length > max_chars
      section += type_header
      total += type_header.length

      items.first(15).each do |artifact|
        line = "- #{artifact.name} (`#{artifact.codebase_file.path}`)\n"
        break if total + line.length > max_chars
        section += line
        total += line.length
      end
      section += "\n"
    end

    section
  end

  def instructions_section
    mr_term = vcs_provider&.merge_request_term || "Pull Request"
    cli = vcs_provider&.cli_tool || "gh"

    <<~INSTRUCTIONS
      ## Instructions
      1. You are working in this repository. It is already cloned and on the default branch.
      2. Create a feature branch: `#{self.branch_name}`
      3. Implement the change described above.
      4. Run the project's test suite. Fix any failures your changes introduce.
      5. Commit your changes with a descriptive message.
      6. Push the branch to origin.
      7. When done, output exactly: <constitution>COMPLETE</constitution>
      8. If you cannot complete the work, output exactly: <constitution>FAILED: {reason}</constitution>

      **VCS:** This is a #{@repository&.provider || "github"} repository. Use `#{cli}` for #{mr_term} operations.
    INSTRUCTIONS
  end

  def vcs_provider
    return nil unless @repository&.provider.present? && @repository.provider != "unknown"

    @vcs_provider ||= Vcs::ProviderFactory.for(@repository)
  rescue RuntimeError
    nil
  end
end
