FactoryBot.define do
  factory :extracted_artifact do
    name { Faker::Internet.slug }
    artifact_type { :model }
    metadata { {} }
    codebase_file
  end
end
