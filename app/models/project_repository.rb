class ProjectRepository < ApplicationRecord
  belongs_to :project
  belongs_to :repository

  validates :repository_id, uniqueness: { scope: :project_id }
end
