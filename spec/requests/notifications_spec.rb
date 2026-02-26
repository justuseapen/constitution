require "rails_helper"

RSpec.describe "Notifications", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }

  before { sign_in user }

  describe "GET /notifications" do
    it "returns notifications" do
      Notification.create!(user: user, message: "Test alert")
      get notifications_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /notifications/unread_count" do
    it "returns unread count" do
      Notification.create!(user: user, message: "Unread", read: false)
      get unread_count_notifications_path(format: :json)
      expect(JSON.parse(response.body)["count"]).to eq(1)
    end
  end
end
