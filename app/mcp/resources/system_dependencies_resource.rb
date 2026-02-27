module Resources
  class SystemDependenciesResource < BaseResource
    def definition
      { uri: "constitution://system/{id}/dependencies", name: "System Dependencies", description: "Dependency graph for a service system", mimeType: "application/json" }
    end

    def matches?(uri)
      uri.match?(%r{^constitution://system/\d+/dependencies$})
    end

    def read(uri)
      system_id = uri.match(%r{system/(\d+)/})[1]
      system = ServiceSystem.find(system_id)
      {
        system: { id: system.id, name: system.name, system_type: system.system_type },
        outgoing: system.outgoing_dependencies.map { |d| { target_id: d.target_system_id, type: d.dependency_type } },
        incoming: system.incoming_dependencies.map { |d| { source_id: d.source_system_id, type: d.dependency_type } }
      }
    end
  end
end
