# frozen_string_literal: true

require "simplecov"
SimpleCov.start "rails" do
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_group "Models", "app/models"
  add_group "Services", "app/services"
  add_group "Clients", "app/clients"
  add_group "Controllers", "app/controllers"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
  minimum_coverage 25
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "webmock/rspec"
require "sidekiq/testing"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# Load support files
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = false

  config.include FactoryBot::Syntax::Methods

  # DatabaseCleaner
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Sidekiq
  config.before do |example|
    if example.metadata[:type] == :integration
      Sidekiq::Testing.inline!
    else
      Sidekiq::Testing.fake!
    end
  end

  # Clean Redis state between tests
  config.before do
    REDIS_POOL.with do |redis|
      redis.keys("alert_state:*").each { |k| redis.del(k) }
      redis.keys("alert_dedup:*").each { |k| redis.del(k) }
      redis.keys("user_alerts:*").each { |k| redis.del(k) }
      redis.keys("alerts:enabled:*").each { |k| redis.del(k) }
      redis.keys("ratelimit:*").each { |k| redis.del(k) }
      redis.keys("circuit:*").each { |k| redis.del(k) }
      redis.keys("cache:*").each { |k| redis.del(k) }
    end
  rescue Redis::CannotConnectError
    # Redis not available in test, skip cleanup
  end

  # WebMock
  WebMock.disable_net_connect!(allow_localhost: true)

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
