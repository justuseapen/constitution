class CodeSearchService
  def self.search(project, query, limit: 10)
    embedding = generate_embedding(query)
    return [] unless embedding

    CodebaseChunk
      .joins(codebase_file: :repository)
      .where(repositories: { service_system_id: project.team.service_systems.select(:id) })
      .nearest_neighbors(:embedding, embedding, distance: "cosine")
      .limit(limit)
  end

  def self.search_by_artifact_type(project, query, artifact_type:, limit: 10)
    embedding = generate_embedding(query)
    return [] unless embedding

    CodebaseChunk
      .joins(codebase_file: { repository: :service_system })
      .joins("INNER JOIN extracted_artifacts ON extracted_artifacts.codebase_file_id = codebase_files.id")
      .where(service_systems: { id: project.team.service_systems.select(:id) })
      .where(extracted_artifacts: { artifact_type: artifact_type })
      .nearest_neighbors(:embedding, embedding, distance: "cosine")
      .limit(limit)
  end

  private

  def self.generate_embedding(text)
    return nil unless defined?(OPENROUTER_CLIENT) && OPENROUTER_CLIENT.present?

    response = OPENROUTER_CLIENT.embeddings(
      parameters: { model: "openai/text-embedding-3-small", input: text.truncate(8000) }
    )
    response.dig("data", 0, "embedding")
  rescue StandardError => e
    Rails.logger.error("Embedding generation failed: #{e.message}")
    nil
  end
end
