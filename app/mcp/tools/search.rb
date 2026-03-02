module Tools
  class Search < BaseTool
    def name
      "constitution.search"
    end

    def definition
      {
        name: name,
        description: "Search across all artifact types (documents, blueprints, work orders, code) using full-text and semantic search",
        inputSchema: {
          type: "object",
          properties: {
            api_token: { type: "string", description: "API authentication token" },
            project_id: { type: "integer", description: "Project ID" },
            query: { type: "string", description: "Search query" },
            artifact_types: { type: "array", items: { type: "string" }, description: "Filter by types: documents, blueprints, work_orders, code" }
          },
          required: [ "api_token", "project_id", "query" ]
        }
      }
    end

    def call(arguments)
      user = authenticate!(arguments)
      project = find_project(user, arguments["project_id"])
      query = arguments["query"]
      types = arguments["artifact_types"] || %w[documents blueprints work_orders code]
      results = {}

      if types.include?("documents")
        results[:documents] = project.documents
          .where("title ILIKE :q OR body ILIKE :q", q: "%#{query}%")
          .limit(10)
          .map { |d| { id: d.id, title: d.title, type: d.document_type, snippet: d.body&.truncate(200) } }
      end

      if types.include?("blueprints")
        results[:blueprints] = project.blueprints
          .where("title ILIKE :q OR body ILIKE :q", q: "%#{query}%")
          .limit(10)
          .map { |b| { id: b.id, title: b.title, type: b.blueprint_type, snippet: b.body&.truncate(200) } }
      end

      if types.include?("work_orders")
        results[:work_orders] = project.work_orders
          .where("title ILIKE :q OR description ILIKE :q", q: "%#{query}%")
          .limit(10)
          .map { |w| { id: w.id, title: w.title, status: w.status, snippet: w.description&.truncate(200) } }
      end

      if types.include?("code")
        code_results = CodeSearchService.search(project, query, limit: 10)
        results[:code] = Array(code_results).map { |c| { file: c.codebase_file.path, chunk_type: c.chunk_type, lines: "#{c.start_line}-#{c.end_line}", snippet: c.content.truncate(200) } }
      end

      results
    end
  end
end
