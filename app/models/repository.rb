class Repository < ApplicationRecord
  include GraphSync

  belongs_to :service_system
  has_many :codebase_files, dependent: :destroy

  enum :provider, { github: 0, gitlab: 1, unknown: 2 }

  validates :name, presence: true
  validates :url, presence: true, uniqueness: { scope: :service_system_id, message: "has already been imported" }
  validate :valid_git_url

  private

  def valid_git_url
    return if url.blank?

    valid_patterns = [
      %r{\Ahttps?://[^/]+/.+\.git\z},           # HTTPS: https://github.com/owner/repo.git
      %r{\Ahttps?://[^/]+/.+\z},                 # HTTPS without .git: https://github.com/owner/repo
      %r{\Agit@[^:]+:[^/]+/.+\.git\z},           # SSH: git@github.com:owner/repo.git
      %r{\Agit@[^:]+:[^/]+/.+\z},                # SSH without .git: git@github.com:owner/repo
      %r{\Assh://git@[^/]+/.+\z}                 # SSH explicit: ssh://git@gitlab.com/owner/repo.git
    ]

    unless valid_patterns.any? { |pattern| url.match?(pattern) }
      errors.add(:url, "must be a valid git URL (HTTPS or SSH)")
    end
  end

  enum :indexing_status, {
    pending: 0,
    indexing: 1,
    indexed: 2,
    failed: 3
  }
end
