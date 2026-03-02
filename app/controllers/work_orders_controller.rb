class WorkOrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :set_work_order, only: [:show, :edit, :update, :destroy, :execute, :cancel_execution]

  def index
    @work_orders = @project.work_orders.includes(:assignee, :phase).order(:position)
  end

  def show
  end

  def new
    @work_order = @project.work_orders.build
  end

  def create
    @work_order = @project.work_orders.build(work_order_params)
    if @work_order.save
      redirect_to project_work_order_path(@project, @work_order), notice: "Work order created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @work_order.update(work_order_params)
      respond_to do |format|
        format.html { redirect_to project_work_order_path(@project, @work_order), notice: "Work order updated." }
        format.turbo_stream
        format.json { head :ok }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @work_order.destroy
    redirect_to project_work_orders_path(@project), notice: "Work order deleted."
  end

  def execute
    if @work_order.executions.where(status: [:queued, :running]).exists?
      redirect_to project_work_order_path(@project, @work_order), alert: "An execution is already running."
      return
    end

    execution = @work_order.executions.create!(
      triggered_by: current_user,
      status: :queued
    )

    WorkOrderExecutionJob.perform_later(execution.id)

    redirect_to project_work_order_path(@project, @work_order), notice: "Agent execution started."
  end

  def cancel_execution
    execution = @work_order.executions.where(status: [:queued, :running]).order(created_at: :desc).first

    unless execution
      redirect_to project_work_order_path(@project, @work_order), alert: "No running execution to cancel."
      return
    end

    if execution.pid.present?
      begin
        Process.kill("TERM", execution.pid)
      rescue Errno::ESRCH
        # Process already exited
      end
    end

    execution.update!(
      status: :failed,
      error_message: "Cancelled by user",
      completed_at: Time.current
    )
    @work_order.update!(status: :todo) if @work_order.in_progress?

    redirect_to project_work_order_path(@project, @work_order), notice: "Execution cancelled."
  end

  private

  def set_project
    @project = current_user.team.projects.find(params[:project_id])
  end

  def set_work_order
    @work_order = @project.work_orders.find(params[:id])
  end

  def work_order_params
    params.require(:work_order).permit(
      :title, :description, :acceptance_criteria, :implementation_plan,
      :status, :priority, :position, :phase_id, :assignee_id
    )
  end
end
