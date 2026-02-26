FactoryBot.define do
  factory :service_system do
    name { Faker::App.name }
    description { Faker::Lorem.sentence }
    system_type { :service }
    team
  end
end
