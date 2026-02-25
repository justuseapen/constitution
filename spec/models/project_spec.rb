require "rails_helper"

RSpec.describe Project, type: :model do
  it { should validate_presence_of(:name) }
  it { should belong_to(:team) }
  it { should have_many(:documents) }
  it { should have_many(:blueprints) }
  it { should have_many(:phases) }
  it { should have_many(:work_orders) }
  it { should have_many(:feedback_items) }
  it { should define_enum_for(:status).with_values(active: 0, archived: 1) }
end
