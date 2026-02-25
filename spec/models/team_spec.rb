require "rails_helper"

RSpec.describe Team, type: :model do
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:slug) }
  it { should validate_uniqueness_of(:slug) }
  it { should have_many(:users) }
  it { should have_many(:projects) }
end
