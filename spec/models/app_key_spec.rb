require "rails_helper"
RSpec.describe AppKey, type: :model do
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:token) }
  it { should belong_to(:project) }
  it "generates token on create" do
    key = create(:app_key)
    expect(key.token).to start_with("sf-int-")
  end
end
