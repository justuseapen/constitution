class CodebaseFile < ApplicationRecord
  belongs_to :repository
  has_many :codebase_chunks, dependent: :destroy
  has_many :extracted_artifacts, dependent: :destroy

  validates :path, presence: true
  validates :path, uniqueness: { scope: :repository_id }
end
