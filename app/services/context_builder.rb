class ContextBuilder
  CHARS_PER_TOKEN = 4

  def initialize(project, max_tokens: 8000)
    @project = project
    @max_chars = max_tokens * CHARS_PER_TOKEN
    @sections = []
  end

  def add_document(document)
    @sections << { priority: 1, label: "Current Document", content: format_document(document) }
    self
  end

  def add_graph_neighbors(record)
    neighbors = GraphService.neighbors(record.class.name, record.id)
    neighbor_records = neighbors.map { |n| n[:label].constantize.find_by(id: n[:postgres_id]) }.compact
    neighbor_records.each do |rec|
      @sections << { priority: 2, label: "Linked: #{rec.class.name}", content: format_record(rec) }
    end
    self
  end

  def add_system_dependencies(systems)
    Array(systems).each do |system|
      deps = GraphService.neighbors("System", system.id)
      @sections << { priority: 3, label: "System: #{system.name}", content: format_dependencies(system, deps) }
    end
    self
  end

  def add_codebase_snippets(files)
    Array(files).each do |file|
      @sections << { priority: 4, label: "Code: #{file.path}", content: file.content }
    end
    self
  end

  def add_semantic_code_search(query, limit: 5)
    chunks = CodeSearchService.search(@project, query, limit: limit)
    Array(chunks).each do |chunk|
      file = chunk.codebase_file
      @sections << {
        priority: 4,
        label: "Code: #{file.path}:#{chunk.start_line}-#{chunk.end_line}",
        content: chunk.content
      }
    end
    self
  end

  def add_conversation_history(conversation)
    return self unless conversation
    messages = conversation.messages.order(:created_at).last(20)
    content = messages.map { |m| "#{m.role}: #{m.content}" }.join("\n")
    @sections << { priority: 5, label: "Conversation History", content: content }
    self
  end

  def build
    sorted = @sections.sort_by { |s| s[:priority] }
    result = []
    total = 0

    sorted.each do |section|
      section_text = "## #{section[:label]}\n\n#{section[:content]}\n\n"
      break if total + section_text.length > @max_chars
      result << section_text
      total += section_text.length
    end

    result.join
  end

  private

  def format_document(doc)
    "**#{doc.title}** (#{doc.try(:document_type) || doc.try(:blueprint_type)})\n\n#{doc.body}"
  end

  def format_record(rec)
    "**#{rec.try(:title) || rec.try(:name)}**\n#{rec.try(:body) || rec.try(:description)}"
  end

  def format_dependencies(system, deps)
    lines = deps.map { |d| "- #{d[:relationship]} -> #{d[:label]} (ID: #{d[:postgres_id]})" }
    "#{system.name} (#{system.system_type})\n#{lines.join("\n")}"
  end
end
