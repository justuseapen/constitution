require "rails_helper"

RSpec.describe GitImportJob, type: :job do
  it "is enqueued in the default queue" do
    expect(GitImportJob.new.queue_name).to eq("default")
  end
end
