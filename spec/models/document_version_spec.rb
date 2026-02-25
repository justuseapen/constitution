require "rails_helper"

RSpec.describe DocumentVersion, type: :model do
  it { should belong_to(:document) }
  it { should belong_to(:created_by).class_name("User") }
  it { should validate_presence_of(:version_number) }
  it { should validate_presence_of(:body_snapshot) }
end
