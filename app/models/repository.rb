class Repository < ApplicationRecord
  include GraphSync

  belongs_to :service_system
  has_many :codebase_files, dependent: :destroy

  validates :name, presence: true
  validates :url, presence: true

  enum :indexing_status, {
    pending: 0,
    indexing: 1,
    indexed: 2,
    failed: 3
  }
end
