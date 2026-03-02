class WorkOrderExecutionChannel < ApplicationCable::Channel
  def subscribed
    stream_from "execution_#{params[:execution_id]}"
  end
end
