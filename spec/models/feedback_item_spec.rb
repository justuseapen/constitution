require "rails_helper"
RSpec.describe FeedbackItem, type: :model do
  before { allow(GraphService).to receive(:create_node) }
  it { should validate_presence_of(:title) }
  it { should belong_to(:project) }
  it { should have_many(:comments) }
  it { should define_enum_for(:category).with_values(uncategorized: 0, bug: 1, feature_request: 2, performance: 3) }
  it { should define_enum_for(:status).with_values(new_item: 0, triaged: 1, in_progress: 2, resolved: 3, dismissed: 4) }
end
