FactoryBot.define do
  factory :document_version do
    body_snapshot { Faker::Lorem.paragraphs(number: 2).join("\n\n") }
    version_number { 1 }
    document
    created_by { association :user }
  end
end
