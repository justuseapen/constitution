FactoryBot.define do
  factory :agent_message do
    agent_conversation
    role { "user" }
    content { Faker::Lorem.sentence }
  end
end
