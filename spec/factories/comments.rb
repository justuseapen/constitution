FactoryBot.define do
  factory :comment do
    body { Faker::Lorem.paragraph }
    resolved { false }
    user
    commentable { association :document }
  end
end
