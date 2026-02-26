require "rails_helper"

RSpec.describe WorkOrder, type: :model do
  it { should validate_presence_of(:title) }
  it { should belong_to(:project) }
  it { should belong_to(:phase).optional }
  it { should belong_to(:assignee).class_name("User").optional }
  it { should have_many(:comments) }
  it { should define_enum_for(:status).with_values(
    backlog: 0, todo: 1, in_progress: 2, review: 3, done: 4
  ) }
  it { should define_enum_for(:priority).with_values(
    low: 0, medium: 1, high: 2, critical: 3
  ) }
end
