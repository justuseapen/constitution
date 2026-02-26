require "rails_helper"

RSpec.describe CodebaseIndexJob, type: :job do
  let(:repository) { create(:repository) }

  it "is enqueued in the default queue" do
    expect(CodebaseIndexJob.new.queue_name).to eq("default")
  end

  it "updates indexing_status on success" do
    allow_any_instance_of(CodebaseIndexJob).to receive(:clone_or_pull)
    allow_any_instance_of(CodebaseIndexJob).to receive(:index_files)
    allow_any_instance_of(CodebaseIndexJob).to receive(:generate_embeddings)

    CodebaseIndexJob.perform_now(repository.id)

    repository.reload
    expect(repository.indexing_status).to eq("indexed")
    expect(repository.last_indexed_at).to be_present
  end

  it "sets status to failed on error" do
    allow_any_instance_of(CodebaseIndexJob).to receive(:clone_or_pull).and_raise(StandardError, "git error")

    expect {
      CodebaseIndexJob.perform_now(repository.id)
    }.to raise_error(StandardError)

    repository.reload
    expect(repository.indexing_status).to eq("failed")
  end
end
