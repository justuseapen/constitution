class GraphExplorerController < ApplicationController
  before_action :authenticate_user!

  ALLOWED_NODE_TYPES = %w[ServiceSystem Repository ExtractedArtifact].freeze

  def show
    @project = current_user.team.projects.find(params[:project_id]) if params[:project_id].present?
  end

  def neighbors
    node_type = params[:node_type]
    node_id = params[:node_id]
    head(:bad_request) and return unless ALLOWED_NODE_TYPES.include?(node_type)

    neighbors = if GraphService.available?
      GraphService.neighbors(node_type, node_id)
    else
      fallback_neighbors(node_type, node_id)
    end

    render json: { nodes: neighbors[:nodes], edges: neighbors[:edges] }
  end

  def impact_analysis
    node_type = params[:node_type]
    node_id = params[:node_id]
    head(:bad_request) and return unless ALLOWED_NODE_TYPES.include?(node_type)

    result = if GraphService.available?
      GraphService.impact_analysis(node_type, node_id)
    else
      { affected: [], depth: 0 }
    end

    render json: result
  end

  def root_nodes
    systems = current_user.team.service_systems
      .includes(:repositories)

    nodes = systems.map do |sys|
      {
        id: "system_#{sys.id}",
        name: sys.name,
        type: "ServiceSystem",
        system_type: sys.system_type,
        repo_count: sys.repositories.size
      }
    end

    render json: { nodes: nodes }
  end

  private

  def fallback_neighbors(node_type, node_id)
    case node_type
    when "ServiceSystem"
      system = current_user.team.service_systems.find(node_id)
      nodes = system.repositories.map { |r| { id: "repo_#{r.id}", name: r.name, type: "Repository", status: r.indexing_status } }
      edges = nodes.map { |n| { source: "system_#{node_id}", target: n[:id] } }
      { nodes: nodes, edges: edges }
    when "Repository"
      repo = Repository.joins(service_system: :team).where(teams: { id: current_user.team_id }).find(node_id)
      artifacts = repo.codebase_files.includes(:extracted_artifacts).flat_map(&:extracted_artifacts).first(20)
      nodes = artifacts.map { |a| { id: "artifact_#{a.id}", name: a.name, type: a.artifact_type } }
      edges = nodes.map { |n| { source: "repo_#{node_id}", target: n[:id] } }
      { nodes: nodes, edges: edges }
    else
      { nodes: [], edges: [] }
    end
  end
end
