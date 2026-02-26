require "rails_helper"

RSpec.describe AgentConversation, type: :model do
  it { should belong_to(:user) }
  it { should have_many(:messages) }
  it { should validate_presence_of(:model_provider) }
  it { should validate_presence_of(:model_name) }
end
