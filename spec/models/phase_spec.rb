require "rails_helper"

RSpec.describe Phase, type: :model do
  it { should validate_presence_of(:name) }
  it { should belong_to(:project) }
  it { should have_many(:work_orders) }
end
