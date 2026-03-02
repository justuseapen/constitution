class PrValidationJob < ApplicationJob
  queue_as :default

  def perform(execution_id)
    execution = WorkOrderExecution.find(execution_id)

    unless execution.completed? && execution.pull_request_url.present? && execution.repository.present?
      Rails.logger.info("Skipping PR validation for execution #{execution_id}: not eligible")
      return
    end

    review_service = MrReviewService.new(execution: execution)
    result = review_service.review!

    if result
      Notification.create!(
        user_id: execution.triggered_by_id,
        message: "QA review complete for '#{execution.work_order.title}': #{result.dig(:ai, :overall)&.upcase || 'DONE'}",
        notifiable: execution.work_order
      )
    end
  rescue StandardError => e
    Rails.logger.error("PR validation failed for execution #{execution_id}: #{e.message}")
    Notification.create!(
      user_id: execution.triggered_by_id,
      message: "QA review failed for '#{execution.work_order.title}': #{e.message}",
      notifiable: execution.work_order
    ) rescue nil
  end
end
