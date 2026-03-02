FactoryBot.define do
  factory :system_dependency do
    source_system { association :service_system }
    target_system { association :service_system }
    dependency_type { :http_api }
    metadata { { endpoints: [ "/api/v1/users" ] } }
  end
end
