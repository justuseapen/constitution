class BlueprintVersion < ApplicationRecord
  belongs_to :blueprint
  belongs_to :created_by, class_name: "User"

  validates :version_number, presence: true
  validates :body_snapshot, presence: true
end
