require "rails_helper"

RSpec.describe "WorkOrders", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }

  before { sign_in user }

  describe "GET /projects/:project_id/work_orders" do
    it "returns the kanban board" do
      create(:work_order, project: project, title: "Test WO")
      get project_work_orders_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Test WO")
    end
  end

  describe "GET /projects/:project_id/work_orders/:id" do
    it "shows work order details" do
      wo = create(:work_order, project: project)
      get project_work_order_path(project, wo)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(wo.title)
    end
  end

  describe "POST /projects/:project_id/work_orders" do
    it "creates a work order" do
      expect {
        post project_work_orders_path(project), params: {
          work_order: { title: "New WO", description: "Test", status: "todo", priority: "high" }
        }
      }.to change(project.work_orders, :count).by(1)
      expect(response).to redirect_to(project_work_order_path(project, WorkOrder.last))
    end
  end

  describe "PATCH /projects/:project_id/work_orders/:id" do
    it "updates status" do
      wo = create(:work_order, project: project, status: :todo)
      patch project_work_order_path(project, wo),
        params: { work_order: { status: "in_progress" } }
      expect(wo.reload.status).to eq("in_progress")
    end

    it "updates via JSON for kanban drag-and-drop" do
      wo = create(:work_order, project: project, status: :todo)
      patch project_work_order_path(project, wo),
        params: { work_order: { status: "in_progress", position: 1 } },
        as: :json
      expect(wo.reload.status).to eq("in_progress")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /projects/:project_id/work_orders/:id" do
    it "deletes the work order" do
      wo = create(:work_order, project: project)
      expect {
        delete project_work_order_path(project, wo)
      }.to change(project.work_orders, :count).by(-1)
    end
  end
end
