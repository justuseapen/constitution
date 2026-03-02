FactoryBot.define do
  factory :work_order_execution do
    work_order
    triggered_by { association :user, team: work_order.project.team }
    status { :queued }
  end
end
