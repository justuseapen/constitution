class GenerateRequirementsJob < ApplicationJob
  queue_as :default

  def perform(project_id:, user_id:, repository_id:)
    project = Project.find(project_id)
    user = User.find(user_id)
    repository = Repository.find(repository_id)

    artifacts = repository.codebase_files
      .joins(:extracted_artifacts)
      .includes(:extracted_artifacts)
      .limit(100)

    return if artifacts.empty?

    context = build_artifact_summary(artifacts)
    update_or_create_document(project, user, context, :product_overview, "Product Overview")
    update_or_create_document(project, user, context, :technical_requirement, "Technical Requirements")
  end

  private

  def build_artifact_summary(artifacts)
    summary = []
    artifacts.flat_map(&:extracted_artifacts).group_by(&:artifact_type).each do |type, items|
      summary << "## #{type.humanize.pluralize}"
      items.first(20).each { |a| summary << "- #{a.name}" }
    end
    summary.join("\n")
  end

  def update_or_create_document(project, user, context, doc_type, title)
    return unless defined?(OPENROUTER_CLIENT) && OPENROUTER_CLIENT.present?

    prompt = build_prompt(doc_type, context)

    begin
      response = OPENROUTER_CLIENT.chat(
        parameters: {
          model: "anthropic/claude-sonnet-4.5",
          messages: [{ role: "user", content: prompt }]
        }
      )
    rescue Faraday::Error => e
      Rails.logger.error("GenerateRequirementsJob LLM call failed for #{doc_type}: #{e.message}")
      return
    end

    body = response.dig("choices", 0, "message", "content")
    return unless body

    existing = project.documents.find_by(document_type: doc_type)
    if existing
      existing.create_version!(user)
      existing.update!(body: body, updated_by: user, status: "ai_generated")
    else
      project.documents.create!(
        title: title,
        body: body,
        document_type: doc_type,
        created_by: user,
        status: "ai_generated"
      )
    end
  end

  def build_prompt(doc_type, context)
    case doc_type
    when :product_overview
      <<~PROMPT
        Based on the following extracted code artifacts from a repository, generate a Product Overview document.
        Include these sections as HTML headings (<h2>) with substantive content:
        - What the application does (inferred from models, routes, and services)
        - Key technologies and frameworks used
        - Target users (inferred from the domain and features)
        - Core features and capabilities

        Format the output as clean HTML suitable for a rich text editor. Use <h2> for headings and <p> for paragraphs.
        Do NOT wrap in markdown code fences. Output raw HTML only.

        Artifacts:
        #{context}
      PROMPT
    when :technical_requirement
      <<~PROMPT
        Based on the following extracted code artifacts from a repository, generate a Technical Requirements document.
        Include these sections as HTML headings (<h2>) with substantive content:
        - Data Models (list the key models and their relationships)
        - API Routes and Endpoints
        - Services and Business Logic
        - Infrastructure and Dependencies
        - Authentication and Authorization (if present)
        - Performance Considerations

        Format the output as clean HTML suitable for a rich text editor. Use <h2> for headings and <p> for paragraphs.
        Do NOT wrap in markdown code fences. Output raw HTML only.

        Artifacts:
        #{context}
      PROMPT
    end
  end
end
