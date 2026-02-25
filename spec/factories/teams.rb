FactoryBot.define do
  factory :team do
    name { Faker::Company.name }
    slug { name.parameterize }
  end
end
