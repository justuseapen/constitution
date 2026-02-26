FactoryBot.define do
  factory :feedback_item do
    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraph }
    category { :uncategorized }
    status { :new_item }
    project
  end
end
