require "rails_helper"

RSpec.describe Comment, type: :model do
  it { should validate_presence_of(:body) }
  it { should belong_to(:commentable) }
  it { should belong_to(:user) }

  it "can be attached to a document" do
    document = create(:document)
    comment = create(:comment, commentable: document)
    expect(document.comments).to include(comment)
  end
end
