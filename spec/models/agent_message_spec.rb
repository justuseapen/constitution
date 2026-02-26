require "rails_helper"

RSpec.describe AgentMessage, type: :model do
  it { should belong_to(:agent_conversation) }
  it { should validate_presence_of(:role) }
  it { should validate_inclusion_of(:role).in_array(%w[system user assistant]) }
end
