module Api
  module V1
    class FeedbackController < ActionController::API
      before_action :authenticate_app_key!

      def create
        @feedback = @project.feedback_items.build(feedback_params)
        if @feedback.save
          render json: { id: @feedback.id, status: "created" }, status: :created
        else
          render json: { errors: @feedback.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def authenticate_app_key!
        token = request.headers["Authorization"]&.delete_prefix("Bearer ")
        app_key = AppKey.active.find_by(token: token)
        if app_key
          @project = app_key.project
        else
          render json: { error: "Invalid or inactive API key" }, status: :unauthorized
        end
      end

      def feedback_params
        params.permit(:title, :body, :source, :submitted_by_email, technical_context: {})
      end
    end
  end
end
