class BlueprintsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :set_blueprint, only: [ :show, :edit, :update, :destroy ]

  def index
    @blueprints = @project.blueprints.order(created_at: :desc)
  end

  def show
  end

  def new
    @blueprint = @project.blueprints.build
  end

  def create
    @blueprint = @project.blueprints.build(blueprint_params)
    @blueprint.created_by = current_user
    if @blueprint.save
      redirect_to project_blueprint_path(@project, @blueprint), notice: "Blueprint created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @blueprint.updated_by = current_user
    if @blueprint.update(blueprint_params)
      @blueprint.create_version!(current_user)
      redirect_to project_blueprint_path(@project, @blueprint), notice: "Blueprint updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @blueprint.destroy
    redirect_to project_blueprints_path(@project), notice: "Blueprint deleted."
  end

  private

  def set_project
    @project = current_user.team.projects.find(params[:project_id])
  end

  def set_blueprint
    @blueprint = @project.blueprints.find(params[:id])
  end

  def blueprint_params
    params.require(:blueprint).permit(:title, :body, :blueprint_type, :document_id)
  end
end
