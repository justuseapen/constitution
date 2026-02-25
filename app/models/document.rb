class Document < ApplicationRecord
  belongs_to :project
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :versions, class_name: "DocumentVersion", dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true

  enum :document_type, {
    product_overview: 0,
    feature_requirement: 1,
    technical_requirement: 2
  }

  after_initialize { self.version ||= 0 }

  def create_version!(user)
    new_version = version + 1
    versions.create!(
      body_snapshot: body,
      version_number: new_version,
      created_by_id: user.id
    )
    update!(version: new_version)
  end
end
