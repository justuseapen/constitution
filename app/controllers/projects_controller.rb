class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  def index
    @projects = current_user.team.projects.order(created_at: :desc)
  end

  def show
  end

  def new
    @project = current_user.team.projects.build
  end

  def create
    @project = current_user.team.projects.build(project_params)
    if @project.save
      Project.seed_documents(@project, current_user)
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted."
  end

  private

  def set_project
    @project = current_user.team.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
