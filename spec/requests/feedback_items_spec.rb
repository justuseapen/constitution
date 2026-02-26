require "rails_helper"

RSpec.describe "FeedbackItems", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }

  before do
    sign_in user
    allow(GraphService).to receive(:create_node)
    allow(GraphService).to receive(:create_edge)
  end

  describe "GET /projects/:project_id/feedback_items" do
    it "shows inbox" do
      create(:feedback_item, project: project, title: "Bug report")
      get project_feedback_items_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bug report")
    end
  end

  describe "POST /projects/:project_id/feedback_items/:id/create_work_order" do
    it "creates a work order from feedback" do
      fi = create(:feedback_item, project: project)
      expect {
        post create_work_order_project_feedback_item_path(project, fi)
      }.to change(WorkOrder, :count).by(1)
      expect(response).to redirect_to(project_work_order_path(project, WorkOrder.last))
    end
  end
end
