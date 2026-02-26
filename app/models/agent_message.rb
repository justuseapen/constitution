class AgentMessage < ApplicationRecord
  belongs_to :agent_conversation

  validates :role, presence: true, inclusion: { in: %w[system user assistant] }
end
