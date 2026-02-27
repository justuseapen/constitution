RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system

  config.before(:suite) do
    Rails.application.reload_routes!
    Warden.test_mode!
  end

  config.after(:each) do
    Warden.test_reset!
  end
end
