require "rails_helper"

RSpec.describe Repository, type: :model do
  it { should belong_to(:service_system) }
  it { should have_many(:codebase_files).dependent(:destroy) }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:url) }
  it { should define_enum_for(:indexing_status).with_values(pending: 0, indexing: 1, indexed: 2, failed: 3) }
end
