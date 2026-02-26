class FeedbackItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :set_feedback_item, only: [:show, :update, :create_work_order]

  def index
    @feedback_items = @project.feedback_items.order(created_at: :desc)
    @feedback_items = @feedback_items.where(category: params[:category]) if params[:category].present?
    @feedback_items = @feedback_items.where(status: params[:status]) if params[:status].present?
  end

  def show
  end

  def update
    @feedback_item.update!(feedback_item_params)
    redirect_to project_feedback_item_path(@project, @feedback_item), notice: "Feedback updated."
  end

  def create_work_order
    work_order = @project.work_orders.create!(
      title: "[Feedback] #{@feedback_item.title}",
      description: @feedback_item.body,
      acceptance_criteria: "Resolve feedback: #{@feedback_item.title}",
      status: :backlog
    )
    GraphService.create_edge(
      from: { label: "FeedbackItem", postgres_id: @feedback_item.id },
      to: { label: "WorkOrder", postgres_id: work_order.id },
      type: "GENERATES"
    )
    @feedback_item.update!(status: :in_progress)
    redirect_to project_work_order_path(@project, work_order), notice: "Work order created from feedback."
  end

  private

  def set_project
    @project = current_user.team.projects.find(params[:project_id])
  end

  def set_feedback_item
    @feedback_item = @project.feedback_items.find(params[:id])
  end

  def feedback_item_params
    params.require(:feedback_item).permit(:status, :category)
  end
end
