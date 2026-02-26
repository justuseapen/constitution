class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications.recent
    respond_to do |format|
      format.html
      format.json { render json: @notifications }
    end
  end

  def mark_read
    current_user.notifications.where(id: params[:ids]).update_all(read: true)
    head :ok
  end

  def unread_count
    render json: { count: current_user.notifications.unread.count }
  end
end
