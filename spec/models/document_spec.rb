require "rails_helper"

RSpec.describe Document, type: :model do
  it { should validate_presence_of(:title) }
  it { should belong_to(:project) }
  it { should belong_to(:created_by).class_name("User") }
  it { should belong_to(:updated_by).class_name("User").optional }
  it { should have_many(:versions).class_name("DocumentVersion") }
  it { should have_many(:comments).as(:commentable) }
  it { should define_enum_for(:document_type).with_values(
    product_overview: 0,
    feature_requirement: 1,
    technical_requirement: 2
  ) }

  describe "#create_version!" do
    it "snapshots the current body and increments version" do
      document = create(:document, body: "v1 content")
      document.create_version!(create(:user))
      expect(document.versions.count).to eq(1)
      expect(document.versions.last.body_snapshot).to eq("v1 content")
      expect(document.versions.last.version_number).to eq(1)
    end
  end
end
