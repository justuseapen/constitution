FactoryBot.define do
  factory :document do
    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    document_type { :feature_requirement }
    project
    created_by { association :user }
  end
end
