class Blueprint < ApplicationRecord
  belongs_to :project
  belongs_to :document, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :versions, class_name: "BlueprintVersion", dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true

  enum :blueprint_type, {
    foundation: 0,
    system_diagram: 1,
    feature_blueprint: 2
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
