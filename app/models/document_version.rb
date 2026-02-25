class DocumentVersion < ApplicationRecord
  belongs_to :document
  belongs_to :created_by, class_name: "User"

  validates :version_number, presence: true
  validates :body_snapshot, presence: true
end
