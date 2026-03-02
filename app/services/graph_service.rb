class GraphService
  class << self
    def create_node(label, properties)
      return nil unless available?
      execute(
        "MERGE (n:#{label} {postgres_id: $id}) SET n += $props",
        id: properties[:postgres_id],
        props: properties.except(:postgres_id)
      )
    end

    def delete_node(label, postgres_id)
      return nil unless available?
      execute(
        "MATCH (n:#{label} {postgres_id: $id}) DETACH DELETE n",
        id: postgres_id
      )
    end

    def create_edge(from:, to:, type:, properties: {})
      return nil unless available?
      execute(
        "MATCH (a:#{from[:label]} {postgres_id: $from_id}) " \
        "MATCH (b:#{to[:label]} {postgres_id: $to_id}) " \
        "MERGE (a)-[r:#{type}]->(b) SET r += $props",
        from_id: from[:postgres_id],
        to_id: to[:postgres_id],
        props: properties
      )
    end

    def delete_edge(from:, to:, type:)
      return nil unless available?
      execute(
        "MATCH (a:#{from[:label]} {postgres_id: $from_id})" \
        "-[r:#{type}]->" \
        "(b:#{to[:label]} {postgres_id: $to_id}) DELETE r",
        from_id: from[:postgres_id],
        to_id: to[:postgres_id]
      )
    end

    def neighbors(label, postgres_id, direction: :both)
      return [] unless available?
      arrow = case direction
      when :outgoing then "-[r]->"
      when :incoming then "<-[r]-"
      else "-[r]-"
      end

      results = execute(
        "MATCH (n:#{label} {postgres_id: $id})#{arrow}(m) " \
        "RETURN labels(m)[0] AS label, m.postgres_id AS postgres_id, type(r) AS relationship",
        id: postgres_id
      )
      results.map { |r| { label: r[:label], postgres_id: r[:postgres_id], relationship: r[:relationship] } }
    end

    def impact_analysis(label, postgres_id, depth: 3)
      return [] unless available?
      execute(
        "MATCH path = (n:#{label} {postgres_id: $id})-[*1..#{depth}]->(m) " \
        "RETURN [node in nodes(path) | {label: labels(node)[0], id: node.postgres_id}] AS chain",
        id: postgres_id
      )
    end

    def available?
      defined?(NEO4J_DRIVER) && NEO4J_DRIVER.present?
    end

    def execute(query, **params)
      return [] unless available?
      session = NEO4J_DRIVER.session
      result = session.run(query, **params)
      result.to_a.map { |record| record.to_h }
    ensure
      session&.close
    end
  end
end
