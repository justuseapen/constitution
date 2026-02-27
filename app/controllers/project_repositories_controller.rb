class ProjectRepositoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project

  def create
    url = params[:repository_url]&.strip

    if url.blank?
      redirect_to @project, alert: "Repository URL is required."
      return
    end

    GitImportJob.perform_later(
      project_id: @project.id,
      user_id: current_user.id,
      url: url
    )

    redirect_to @project, notice: "Repository import started. Indexing will run in the background."
  end

  def retry_index
    repo = Repository.find(params[:id])
    repo.update_column(:indexing_status, 0) # pending
    CodebaseIndexJob.perform_later(repo.id)
    redirect_to @project, notice: "Re-indexing started for #{repo.name}."
  end

  private

  def set_project
    @project = current_user.team.projects.find(params[:project_id])
  end
end
