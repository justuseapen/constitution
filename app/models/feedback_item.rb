class FeedbackItem < ApplicationRecord
  include GraphSync

  belongs_to :project
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true

  enum :category, { uncategorized: 0, bug: 1, feature_request: 2, performance: 3 }, default: :uncategorized
  enum :status, { new_item: 0, triaged: 1, in_progress: 2, resolved: 3, dismissed: 4 }, default: :new_item

  after_create_commit :enqueue_triage

  private

  def enqueue_triage
    FeedbackTriageJob.perform_later(id)
  end
end
