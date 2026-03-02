class ExtractedArtifact < ApplicationRecord
  include GraphSync

  belongs_to :codebase_file

  validates :name, presence: true
  validates :artifact_type, presence: true

  enum :artifact_type, {
    route: 0,
    controller: 1,
    model: 2,
    service: 3,
    api_client: 4,
    event_emitter: 5,
    queue_publisher: 6,
    queue_consumer: 7,
    protobuf: 8,
    openapi_spec: 9
  }, prefix: true
end
