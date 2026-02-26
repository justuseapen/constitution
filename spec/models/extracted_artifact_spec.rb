require "rails_helper"

RSpec.describe ExtractedArtifact, type: :model do
  it { should belong_to(:codebase_file) }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:artifact_type) }
  it { should define_enum_for(:artifact_type).with_values(
    route: 0, controller: 1, model: 2, service: 3, api_client: 4,
    event_emitter: 5, queue_publisher: 6, queue_consumer: 7, protobuf: 8, openapi_spec: 9
  ) }
end
