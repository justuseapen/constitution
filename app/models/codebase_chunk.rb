class CodebaseChunk < ApplicationRecord
  belongs_to :codebase_file

  has_neighbors :embedding

  validates :content, presence: true
end
