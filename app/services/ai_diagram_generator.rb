class AiDiagramGenerator
  def sequence_diagram_for_route(route_artifact)
    related_artifacts = find_related_artifacts(route_artifact)
    source_context = build_source_context(route_artifact, related_artifacts)

    prompt = build_prompt(route_artifact, source_context)
    generate_mermaid(prompt)
  end

  def system_interaction_diagram(service_system)
    artifacts = service_system.repositories
      .includes(codebase_files: :extracted_artifacts)
      .flat_map { |r| r.codebase_files.flat_map(&:extracted_artifacts) }

    external_artifacts = artifacts.select { |a| a.artifact_type_api_client? || a.artifact_type_queue_publisher? || a.artifact_type_queue_consumer? }
    return nil if external_artifacts.empty?

    prompt = <<~PROMPT
      Generate a Mermaid sequence diagram showing how this system interacts with external systems.

      ## External Interaction Artifacts
      #{external_artifacts.map { |a| "- #{a.artifact_type}: #{a.name} (#{a.codebase_file.path})" }.join("\n")}

      Return ONLY the Mermaid code for a sequence diagram, no explanation.
    PROMPT

    generate_mermaid(prompt)
  end

  private

  def find_related_artifacts(route_artifact)
    repository = route_artifact.codebase_file.repository
    all_artifacts = repository.codebase_files
      .includes(:extracted_artifacts)
      .flat_map(&:extracted_artifacts)

    route_name = route_artifact.name.downcase

    all_artifacts.select do |a|
      next false if a == route_artifact

      # Find artifacts whose name appears in the route's file content
      content = route_artifact.codebase_file.content&.downcase || ""
      [ a.name.underscore, a.name.camelize, a.name ].map(&:downcase).any? { |n| content.include?(n) }
    end
  end

  def build_source_context(route_artifact, related_artifacts)
    parts = [ "### #{route_artifact.name} (#{route_artifact.codebase_file.path})\n" ]
    parts << route_artifact.codebase_file.content.to_s.truncate(2000)

    related_artifacts.first(5).each do |a|
      parts << "\n### #{a.name} (#{a.codebase_file.path})\n"
      parts << a.codebase_file.content.to_s.truncate(1000)
    end

    parts.join("\n")
  end

  def build_prompt(route_artifact, source_context)
    <<~PROMPT
      Generate a Mermaid sequence diagram for the following route/endpoint.
      Show the request flow: client -> route -> controller -> service -> model -> external systems.

      ## Route: #{route_artifact.name}

      ## Source Code
      #{source_context}

      Return ONLY the Mermaid code for a sequence diagram. No markdown fences, no explanation.
      Start with "sequenceDiagram".
    PROMPT
  end

  def generate_mermaid(prompt)
    response = OPENROUTER_CLIENT.chat(
      parameters: {
        model: "anthropic/claude-sonnet-4-5",
        messages: [ { role: "user", content: prompt } ],
        max_tokens: 2000
      }
    )

    content = response.dig("choices", 0, "message", "content")
    return nil unless content

    # Extract just the Mermaid code
    if content.include?("```mermaid")
      content.match(/```mermaid\n(.*?)```/m)&.[](1)&.strip || content.strip
    elsif content.include?("```")
      content.match(/```\n?(.*?)```/m)&.[](1)&.strip || content.strip
    else
      content.strip
    end
  rescue StandardError => e
    Rails.logger.warn("AI diagram generation failed: #{e.message}")
    nil
  end
end
