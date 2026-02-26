FactoryBot.define do
  factory :phase do
    name { Faker::Lorem.word.capitalize }
    position { 0 }
    project
  end
end
