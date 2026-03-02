class SystemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_system, only: [ :show, :edit, :update, :destroy, :architecture, :generate_diagram ]

  def index
    @systems = current_user.team.service_systems.includes(:outgoing_dependencies)
    respond_to do |format|
      format.html
      format.json {
        render json: {
          nodes: @systems.map { |s| { id: s.id, name: s.name, type: s.system_type } },
          edges: SystemDependency.where(source_system: @systems).map { |d|
            { source: d.source_system_id, target: d.target_system_id, type: d.dependency_type, metadata: d.metadata }
          }
        }
      }
    end
  end

  def show
  end

  def architecture
    @repositories = @system.repositories.includes(codebase_files: :extracted_artifacts)
    generator = MermaidGenerator.new

    @diagrams = @repositories.map do |repo|
      {
        repository: repo,
        flowchart: generator.dependency_flowchart(repo),
        class_diagram: generator.model_class_diagram(repo)
      }
    end
  end

  def generate_diagram
    artifact = ExtractedArtifact.joins(codebase_file: :repository)
      .where(repositories: { service_system_id: @system.id })
      .find(params[:artifact_id])

    generator = AiDiagramGenerator.new
    mermaid = generator.sequence_diagram_for_route(artifact)

    render json: { mermaid: mermaid }
  end

  def new
    @system = current_user.team.service_systems.build
  end

  def create
    @system = current_user.team.service_systems.build(system_params)
    if @system.save
      redirect_to systems_path, notice: "System created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @system.update(system_params)
      redirect_to system_path(@system), notice: "System updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @system.destroy
    redirect_to systems_path, notice: "System deleted."
  end

  private

  def set_system
    @system = current_user.team.service_systems.find(params[:id])
  end

  def system_params
    params.require(:service_system).permit(:name, :description, :repo_url, :system_type)
  end
end
