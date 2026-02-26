FactoryBot.define do
  factory :repository do
    name { Faker::App.name.parameterize }
    url { "https://github.com/example/#{name}.git" }
    default_branch { "main" }
    indexing_status { :pending }
    service_system
  end
end
