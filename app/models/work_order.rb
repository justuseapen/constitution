class WorkOrder < ApplicationRecord
  include GraphSync

  belongs_to :project
  belongs_to :phase, optional: true
  belongs_to :assignee, class_name: "User", optional: true
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :agent_conversations, as: :conversable, dependent: :destroy
  has_many :executions, class_name: "WorkOrderExecution", dependent: :destroy

  validates :title, presence: true

  enum :status, {
    backlog: 0,
    todo: 1,
    in_progress: 2,
    review: 3,
    done: 4
  }, default: :backlog

  enum :priority, {
    low: 0,
    medium: 1,
    high: 2,
    critical: 3
  }, default: :medium

  after_update_commit -> {
    broadcast_replace_to(
      "project_#{project_id}_work_orders",
      target: "work_order_#{id}",
      partial: "work_orders/work_order_card"
    )
  }
end
