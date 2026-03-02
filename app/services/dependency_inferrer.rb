class DependencyInferrer
  def initialize(repository)
    @repository = repository
    @system = repository.service_system
    @team = @system.team
  end

  def infer!
    infer_from_api_clients
    infer_from_queue_artifacts
  end

  private

  def infer_from_api_clients
    api_clients = artifacts_by_type(:api_client)

    api_clients.each do |artifact|
      target_system = resolve_target_system(artifact)
      next unless target_system && target_system.id != @system.id

      create_dependency(
        source: @system,
        target: target_system,
        type: :http_api,
        metadata: { inferred_from: artifact.name, artifact_id: artifact.id }
      )
    end
  end

  def infer_from_queue_artifacts
    publishers = artifacts_by_type(:queue_publisher)
    consumers = artifacts_by_type(:queue_consumer)

    # Publishers: this system publishes to a queue consumed by another system
    publishers.each do |pub|
      queue_name = extract_queue_name(pub)
      next unless queue_name

      # Find consumer artifacts in other systems that match this queue
      matching_consumers = ExtractedArtifact
        .joins(codebase_file: { repository: :service_system })
        .where(artifact_type: :queue_consumer)
        .where.not(service_systems: { id: @system.id })
        .where(service_systems: { team_id: @team.id })

      matching_consumers.each do |consumer|
        consumer_queue = extract_queue_name(consumer)
        next unless consumer_queue == queue_name

        target_system = consumer.codebase_file.repository.service_system
        create_dependency(
          source: @system,
          target: target_system,
          type: :rabbitmq,
          metadata: { queue: queue_name, publisher: pub.name, consumer: consumer.name }
        )
      end
    end

    # Consumers: another system publishes to a queue this system consumes
    consumers.each do |con|
      queue_name = extract_queue_name(con)
      next unless queue_name

      matching_publishers = ExtractedArtifact
        .joins(codebase_file: { repository: :service_system })
        .where(artifact_type: :queue_publisher)
        .where.not(service_systems: { id: @system.id })
        .where(service_systems: { team_id: @team.id })

      matching_publishers.each do |pub|
        pub_queue = extract_queue_name(pub)
        next unless pub_queue == queue_name

        source_system = pub.codebase_file.repository.service_system
        create_dependency(
          source: source_system,
          target: @system,
          type: :rabbitmq,
          metadata: { queue: queue_name, publisher: pub.name, consumer: con.name }
        )
      end
    end
  end

  def resolve_target_system(api_client_artifact)
    name = api_client_artifact.name.downcase
    content = api_client_artifact.codebase_file&.content || ""

    # Try matching by URL patterns in the source code
    urls = content.scan(%r{https?://[^\s"']+}).map { |u| URI.parse(u).host rescue nil }.compact

    # Try matching by artifact name against known system names
    other_systems = @team.service_systems.where.not(id: @system.id).includes(:repositories)
    cleaned_name = name.gsub(/client|service|api/, "").strip

    other_systems.each do |sys|
      sys_name = sys.name.downcase.gsub(/[\s_-]/, "")
      return sys if cleaned_name.present? && (name.include?(sys_name) || sys_name.include?(cleaned_name))

      # Match by repository URL hostname
      sys.repositories.each do |repo|
        repo_host = URI.parse(repo.url).host rescue nil
        return sys if repo_host && urls.include?(repo_host)
      end
    end

    nil
  end

  def extract_queue_name(artifact)
    # Try metadata first
    return artifact.metadata["queue_name"] if artifact.metadata&.dig("queue_name")

    # Fallback: extract from artifact name (e.g., "OrdersPublisher" -> "orders")
    artifact.name.gsub(/Publisher|Consumer|Producer|Subscriber/i, "").underscore.strip.presence
  end

  def create_dependency(source:, target:, type:, metadata: {})
    SystemDependency.find_or_create_by!(
      source_system: source,
      target_system: target,
      dependency_type: type
    ) do |dep|
      dep.metadata = { inferred: true, inferred_at: Time.current.iso8601 }.merge(metadata)
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("DependencyInferrer: skipped duplicate dependency: #{e.message}")
  end

  def artifacts_by_type(type)
    ExtractedArtifact
      .joins(codebase_file: :repository)
      .where(repositories: { id: @repository.id })
      .where(artifact_type: type)
  end
end
