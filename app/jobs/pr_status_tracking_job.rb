class PrStatusTrackingJob < ApplicationJob
  queue_as :default

  POLL_INTERVAL = 5.minutes

  def perform
    open_executions = WorkOrderExecution
      .where(status: :completed)
      .where.not(pull_request_url: [ nil, "" ])
      .where(pr_status: [ nil, :pr_open, :pr_approved, :pr_changes_requested ])
      .where.not(repository: nil)
      .includes(:work_order, :repository, :triggered_by)

    open_executions.find_each do |execution|
      check_and_update(execution)
    rescue StandardError => e
      Rails.logger.warn("PR status check failed for execution #{execution.id}: #{e.message}")
    end

    # Re-enqueue if there are still open PRs to track
    if open_executions.reload.exists?
      self.class.set(wait: POLL_INTERVAL).perform_later
    end
  end

  private

  def check_and_update(execution)
    provider = Vcs::ProviderFactory.for(execution.repository)
    pr_identifier = execution.pull_request_url.split("/").last

    new_status = provider.pr_status(pr_identifier: pr_identifier)
    return unless new_status

    mapped_status = map_to_enum(new_status)
    old_status = execution.pr_status

    return if old_status == mapped_status.to_s

    execution.update!(pr_status: mapped_status)

    if %i[pr_merged pr_closed pr_changes_requested].include?(mapped_status)
      Notification.create!(
        user_id: execution.triggered_by_id,
        message: pr_status_message(execution, mapped_status),
        notifiable: execution.work_order
      )
    end
  end

  def map_to_enum(status_symbol)
    case status_symbol
    when :open then :pr_open
    when :approved then :pr_approved
    when :changes_requested then :pr_changes_requested
    when :merged then :pr_merged
    when :closed then :pr_closed
    else :pr_open
    end
  end

  def pr_status_message(execution, status)
    wo_title = execution.work_order.title
    case status.to_sym
    when :pr_merged then "PR for '#{wo_title}' has been merged!"
    when :pr_closed then "PR for '#{wo_title}' was closed."
    when :pr_changes_requested then "Changes requested on PR for '#{wo_title}'."
    else "PR status updated for '#{wo_title}': #{status.to_s.sub('pr_', '')}"
    end
  end
end
