FactoryBot.define do
  factory :agent_conversation do
    conversable { association :document }
    user
    model_provider { "openrouter" }
    model_name { "anthropic/claude-sonnet-4-5-20250929" }
  end
end
