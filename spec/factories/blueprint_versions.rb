FactoryBot.define do
  factory :blueprint_version do
    body_snapshot { Faker::Lorem.paragraphs(number: 2).join("\n\n") }
    version_number { 1 }
    blueprint
    created_by { association :user }
  end
end
