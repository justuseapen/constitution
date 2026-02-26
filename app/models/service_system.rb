class ServiceSystem < ApplicationRecord
  include GraphSync

  belongs_to :team
  has_many :outgoing_dependencies, class_name: "SystemDependency", foreign_key: :source_system_id, dependent: :destroy
  has_many :incoming_dependencies, class_name: "SystemDependency", foreign_key: :target_system_id, dependent: :destroy
  has_many :repositories, dependent: :destroy

  validates :name, presence: true

  enum :system_type, {
    service: 0,
    library: 1,
    database: 2,
    queue: 3,
    external_api: 4
  }

  def graph_label
    "System"
  end

  def graph_properties
    { postgres_id: id, title: name, system_type: system_type }
  end
end
