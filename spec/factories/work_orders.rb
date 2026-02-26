FactoryBot.define do
  factory :work_order do
    title { Faker::Lorem.sentence }
    description { Faker::Lorem.paragraph }
    acceptance_criteria { "- [ ] Criterion 1\n- [ ] Criterion 2" }
    status { :backlog }
    priority { :medium }
    position { 0 }
    project
  end
end
