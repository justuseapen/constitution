# Neo4j Knowledge Graph connection
# Only connect if NEO4J_URL is set (allows running without Neo4j in test)
if ENV["NEO4J_URL"].present?
  require "neo4j/driver"

  NEO4J_DRIVER = Neo4j::Driver::GraphDatabase.driver(
    ENV.fetch("NEO4J_URL", "bolt://localhost:7687"),
    Neo4j::Driver::AuthTokens.basic(
      ENV.fetch("NEO4J_USERNAME", "neo4j"),
      ENV.fetch("NEO4J_PASSWORD", "constitution_dev")
    )
  )

  at_exit { NEO4J_DRIVER.close }
else
  NEO4J_DRIVER = nil
end
