FactoryBot.define do
  factory :notification do
    user
    message { Faker::Lorem.sentence }
    read { false }
    notifiable { association :project }
  end
end
