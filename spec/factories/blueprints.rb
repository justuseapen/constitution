FactoryBot.define do
  factory :blueprint do
    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    blueprint_type { :foundation }
    project
    created_by { association :user }

    trait :system_diagram do
      blueprint_type { :system_diagram }
      body do
        <<~MERMAID
          graph TD
            A[Client] --> B[Load Balancer]
            B --> C[Server 1]
            B --> D[Server 2]
        MERMAID
      end
    end

    trait :feature_blueprint do
      blueprint_type { :feature_blueprint }
      document
    end
  end
end
