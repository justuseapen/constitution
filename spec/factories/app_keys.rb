FactoryBot.define do
  factory :app_key do
    name { Faker::App.name }
    project
  end
end
