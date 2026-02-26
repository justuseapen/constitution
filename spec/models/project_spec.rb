require "rails_helper"

RSpec.describe Project, type: :model do
  it { should validate_presence_of(:name) }
  it { should belong_to(:team) }
  it { should have_many(:documents) }
  it { should have_many(:blueprints) }
  it { should have_many(:phases) }
  it { should have_many(:work_orders) }
  it { should have_many(:feedback_items) }
  it { should define_enum_for(:status).with_values(active: 0, archived: 1) }

  describe ".seed_documents" do
    let(:team) { create(:team) }
    let(:user) { create(:user, team: team) }
    let(:project) { create(:project, team: team) }

    it "creates two placeholder documents" do
      expect {
        Project.seed_documents(project, user)
      }.to change { project.documents.count }.by(2)
    end

    it "creates a Product Overview document" do
      Project.seed_documents(project, user)
      doc = project.documents.find_by(document_type: :product_overview)
      expect(doc).to be_present
      expect(doc.title).to eq("Product Overview")
      expect(doc.body).to include("Business Problem")
      expect(doc.body).to include("Target Users")
      expect(doc.body).to include("Success Criteria")
      expect(doc.created_by).to eq(user)
    end

    it "creates a Technical Requirements document" do
      Project.seed_documents(project, user)
      doc = project.documents.find_by(document_type: :technical_requirement)
      expect(doc).to be_present
      expect(doc.title).to eq("Technical Requirements")
      expect(doc.body).to include("Authentication &amp; Authorization")
      expect(doc.body).to include("Performance")
      expect(doc.body).to include("Security")
      expect(doc.created_by).to eq(user)
    end
  end
end
