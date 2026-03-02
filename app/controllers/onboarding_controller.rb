class OnboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_if_onboarded

  def new
  end

  def create
    team_name = params[:team_name]&.strip
    project_name = params[:project_name]&.strip

    if team_name.blank?
      flash.now[:alert] = "Team name is required."
      render :new, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      team = Team.create!(name: team_name)
      current_user.update!(team: team, role: :owner)

      if project_name.present?
        project = team.projects.create!(name: project_name)
        Project.seed_documents(project, current_user)
      end
    end

    redirect_to root_path, notice: "Welcome to Constitution! Your workspace is ready."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.join(", ")
    render :new, status: :unprocessable_entity
  end

  private

  def redirect_if_onboarded
    redirect_to root_path if current_user.team.present?
  end
end
