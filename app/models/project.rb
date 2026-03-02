class Project < ApplicationRecord
  belongs_to :team
  has_many :documents, dependent: :destroy
  has_many :blueprints, dependent: :destroy
  has_many :phases, dependent: :destroy
  has_many :work_orders, dependent: :destroy
  has_many :feedback_items, dependent: :destroy
  has_many :drift_alerts, dependent: :destroy
  has_many :app_keys, dependent: :destroy
  has_many :project_repositories, dependent: :destroy
  has_many :repositories, through: :project_repositories

  validates :name, presence: true

  enum :status, { active: 0, archived: 1 }, default: :active

  def self.seed_documents(project, user)
    project.documents.create!(
      title: "Product Overview",
      body: "<h2>Business Problem</h2><p></p><h2>Target Users</h2><p></p><h2>Success Criteria</h2><p></p>",
      document_type: :product_overview,
      created_by: user
    )
    project.documents.create!(
      title: "Technical Requirements",
      body: "<h2>Authentication &amp; Authorization</h2><p></p><h2>Performance</h2><p></p><h2>Security</h2><p></p>",
      document_type: :technical_requirement,
      created_by: user
    )
  end
end
