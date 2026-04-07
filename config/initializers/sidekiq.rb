Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"), driver: :hiredis }

  config.on(:startup) do
    schedule_file = Rails.root.join("config", "schedule.yml")
    if File.exist?(schedule_file)
      schedule = YAML.safe_load_file(schedule_file, permitted_classes: [Symbol])
      Sidekiq::Cron::Job.load_from_hash(schedule) if schedule.is_a?(Hash)
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"), driver: :hiredis }
end
