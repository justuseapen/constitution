class MermaidGenerator
  MAX_NODES = 40

  SHAPES = {
    "route" => [ "([", "])" ],
    "controller" => [ "[/", "/]" ],
    "model" => [ "[[", "]]" ],
    "service" => [ "{{", "}}" ],
    "api_client" => [ ">", "]" ],
    "event_emitter" => [ "(((", ")))" ],
    "queue_publisher" => [ "[/", "/]" ],
    "queue_consumer" => [ "[\\", "\\]" ],
    "protobuf" => [ "[(", ")]" ],
    "openapi_spec" => [ "[", "]" ]
  }.freeze

  def dependency_flowchart(repository)
    artifacts = repository.codebase_files
      .includes(:extracted_artifacts)
      .flat_map(&:extracted_artifacts)
      .first(MAX_NODES)

    return "flowchart TD\n    empty[No artifacts found]" if artifacts.empty?

    grouped = artifacts.group_by(&:artifact_type)
    lines = [ "flowchart TD" ]

    grouped.each do |type, items|
      lines << "    subgraph #{type.humanize.pluralize}"
      items.each do |a|
        open_shape, close_shape = SHAPES[type] || [ "[", "]" ]
        lines << "        #{node_id(a)}#{open_shape}\"#{escape(a.name)}\"#{close_shape}"
      end
      lines << "    end"
    end

    add_inferred_edges(lines, artifacts)
    lines.join("\n")
  end

  def model_class_diagram(repository)
    models = repository.codebase_files
      .includes(:extracted_artifacts)
      .flat_map(&:extracted_artifacts)
      .select(&:artifact_type_model?)
      .first(MAX_NODES)

    return "classDiagram\n    class Empty[\"No models found\"]" if models.empty?

    lines = [ "classDiagram" ]
    models.each do |m|
      lines << "    class #{sanitize_class_name(m.name)}"
    end
    lines.join("\n")
  end

  private

  def node_id(artifact)
    "#{artifact.artifact_type}_#{artifact.id}"
  end

  def escape(text)
    text.gsub('"', "'").gsub(/[<>]/, "")
  end

  def sanitize_class_name(name)
    name.gsub(/[^a-zA-Z0-9_]/, "_")
  end

  def add_inferred_edges(lines, artifacts)
    artifact_names = artifacts.map { |a| [ a.name.downcase, a ] }.to_h
    file_contents = artifacts.map { |a| [ a, a.codebase_file.content || "" ] }.to_h

    artifacts.each do |source|
      content = file_contents[source]&.downcase || ""
      artifacts.each do |target|
        next if source == target
        next if source.artifact_type == target.artifact_type

        # Check if source file references target name
        target_patterns = [ target.name.underscore, target.name.camelize, target.name ].map(&:downcase).uniq
        if target_patterns.any? { |pattern| content.include?(pattern) }
          lines << "    #{node_id(source)} --> #{node_id(target)}"
        end
      end
    end
  end
end
