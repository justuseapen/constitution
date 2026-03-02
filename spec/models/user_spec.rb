require "rails_helper"

RSpec.describe User, type: :model do
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:email) }
  it { should belong_to(:team).optional }
  it { should define_enum_for(:role).with_values(member: 0, admin: 1, owner: 2) }
end
