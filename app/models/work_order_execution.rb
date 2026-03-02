class WorkOrderExecution < ApplicationRecord
  belongs_to :work_order
  belongs_to :repository, optional: true
  belongs_to :triggered_by, class_name: "User"

  validates :status, presence: true
  validate :only_one_running_per_work_order, if: -> { status_changed? && running? }

  enum :status, {
    queued: 0,
    running: 1,
    completed: 2,
    failed: 3
  }, default: :queued

  scope :latest_first, -> { order(created_at: :desc) }

  def duration
    return nil unless started_at
    (completed_at || Time.current) - started_at
  end

  def append_log(text)
    update!(log: (log || "") + text)
  end

  private

  def only_one_running_per_work_order
    if work_order && WorkOrderExecution.where(work_order: work_order, status: :running).where.not(id: id).exists?
      errors.add(:work_order_id, "already has a running execution")
    end
  end
end
