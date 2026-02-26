class ProjectChannel < ApplicationCable::Channel
  def subscribed
    stream_from "project_#{params[:project_id]}"
  end
end
