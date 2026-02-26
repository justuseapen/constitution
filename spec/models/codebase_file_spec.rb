require "rails_helper"

RSpec.describe CodebaseFile, type: :model do
  it { should belong_to(:repository) }
  it { should have_many(:codebase_chunks).dependent(:destroy) }
  it { should have_many(:extracted_artifacts).dependent(:destroy) }
  it { should validate_presence_of(:path) }
end
