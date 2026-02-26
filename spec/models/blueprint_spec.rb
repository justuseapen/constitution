require "rails_helper"

RSpec.describe Blueprint, type: :model do
  it { should validate_presence_of(:title) }
  it { should belong_to(:project) }
  it { should belong_to(:document).optional }
  it { should belong_to(:created_by).class_name("User") }
  it { should belong_to(:updated_by).class_name("User").optional }
  it { should have_many(:versions).class_name("BlueprintVersion") }
  it { should have_many(:comments).as(:commentable) }
  it { should define_enum_for(:blueprint_type).with_values(
    foundation: 0,
    system_diagram: 1,
    feature_blueprint: 2
  ) }

  describe "#create_version!" do
    it "snapshots the current body and increments version" do
      blueprint = create(:blueprint, body: "v1 content")
      blueprint.create_version!(create(:user))
      expect(blueprint.versions.count).to eq(1)
      expect(blueprint.versions.last.body_snapshot).to eq("v1 content")
      expect(blueprint.versions.last.version_number).to eq(1)
    end
  end
end
