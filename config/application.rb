require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

# Load dotenv early
Dotenv::Rails.load if defined?(Dotenv)

module Stockpulse
  class Application < Rails::Application
    config.load_defaults 8.0

    # Autoload paths
    config.autoload_lib(ignore: %w[assets tasks])
    config.autoload_paths += %W[#{config.root}/app/clients #{config.root}/app/services #{config.root}/app/serializers]

    # API + Views (NOT api_only)
    config.api_only = false

    # Background jobs
    config.active_job.queue_adapter = :sidekiq

    # ActionCable
    config.action_cable.mount_path = "/cable"

    # Timezone
    config.time_zone = "Eastern Time (US & Canada)"
    config.active_record.default_timezone = :utc

    # Generators
    config.generators do |g|
      g.test_framework :rspec,
        fixtures: true,
        view_specs: false,
        helper_specs: false,
        routing_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
      g.orm :active_record, primary_key_type: :bigint
      g.helper false
      g.assets false
    end
  end
end
