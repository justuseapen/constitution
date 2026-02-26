class DriftAlert < ApplicationRecord
  belongs_to :project
  belongs_to :source, polymorphic: true
  belongs_to :target, polymorphic: true

  enum :status, { open: 0, acknowledged: 1, resolved: 2 }, default: :open

  validates :message, presence: true

  scope :unresolved, -> { where.not(status: :resolved) }
end
