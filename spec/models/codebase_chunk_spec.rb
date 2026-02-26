require "rails_helper"

RSpec.describe CodebaseChunk, type: :model do
  it { should belong_to(:codebase_file) }
  it { should validate_presence_of(:content) }
end
