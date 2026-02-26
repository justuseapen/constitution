FactoryBot.define do
  factory :drift_alert do
    project
    source { association :document }
    target { association :blueprint }
    message { "Source was updated since target was last reviewed" }
    status { :open }
  end
end
