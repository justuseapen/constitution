class GenerateRequirementsJob < ApplicationJob
  queue_as :default

  def perform(project_id:, user_id:, repository_id:)
    project = Project.find(project_id)
    user = User.find(user_id)
    repository = Repository.find(repository_id)

    # Wait for indexing to complete
    return requeue(project_id, user_id, repository_id) if repository.indexing?

    artifacts = repository.codebase_files
      .joins(:extracted_artifacts)
      .includes(:extracted_artifacts)
      .limit(100)

    return if artifacts.empty?

    context = build_artifact_summary(artifacts)
    generate_document(project, user, context, :product_overview, "Product Overview (Auto-Generated)")
    generate_document(project, user, context, :technical_requirement, "Technical Requirements (Auto-Generated)")
  end

  private

  def requeue(project_id, user_id, repository_id)
    self.class.set(wait: 30.seconds).perform_later(
      project_id: project_id,
      user_id: user_id,
      repository_id: repository_id
    )
  end

  def build_artifact_summary(artifacts)
    summary = []
    artifacts.flat_map(&:extracted_artifacts).group_by(&:artifact_type).each do |type, items|
      summary << "## #{type.humanize.pluralize}"
      items.first(20).each { |a| summary << "- #{a.name}" }
    end
    summary.join("\n")
  end

  def generate_document(project, user, context, doc_type, title)
    return unless defined?(OPENROUTER_CLIENT) && OPENROUTER_CLIENT.present?

    prompt = <<~PROMPT
      Based on the following extracted code artifacts, generate a #{doc_type.to_s.humanize} document.
      Format the output as HTML suitable for a rich text editor.

      Artifacts:
      #{context}
    PROMPT

    response = OPENROUTER_CLIENT.chat(
      parameters: {
        model: "anthropic/claude-sonnet-4-5-20250929",
        messages: [{ role: "user", content: prompt }]
      }
    )

    body = response.dig("choices", 0, "message", "content")
    return unless body

    existing = project.documents.find_by(title: title)
    if existing
      existing.update!(body: body, updated_by: user)
    else
      project.documents.create!(
        title: title,
        body: body,
        document_type: doc_type,
        created_by: user
      )
    end
  end
end
