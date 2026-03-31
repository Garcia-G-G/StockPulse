source "https://rubygems.org"

ruby ">= 3.3"

# Core
gem "rails", "~> 8.0"
gem "pg", "~> 1.5"
gem "puma", "~> 7.0"
gem "redis", "~> 5.1"
gem "hiredis-client"
gem "connection_pool"
gem "thruster", require: false
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]
gem "propshaft"

# Background Jobs
gem "sidekiq", "~> 8.0"
gem "sidekiq-cron", "~> 2.3"
gem "sidekiq-unique-jobs", "~> 8.0"
gem "sidekiq-throttled"

# API
gem "jbuilder", "~> 2.11"
gem "jsonapi-serializer"
gem "rack-cors"
gem "rack-attack"
gem "pagy", "~> 8.0"
gem "oj"

# HTTP Clients
gem "faraday", "~> 2.14"
gem "faraday-retry"
gem "faraday-multipart"
gem "typhoeus"
gem "faye-websocket"

# Real-time
gem "solid_cable"
gem "turbo-rails"
gem "stimulus-rails"

# Telegram
gem "telegram-bot-ruby", "~> 2.0"

# WhatsApp
gem "twilio-ruby", "~> 7.0"

# Configuration
gem "dotenv-rails"
gem "anyway_config", "~> 2.6"

# Frontend
gem "tailwindcss-rails"
gem "importmap-rails"

# Monitoring
gem "lograge"
gem "amazing_print"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-rails"
  gem "pry-byebug"
  gem "rubocop-rails-omakase", require: false
  gem "brakeman", require: false
  gem "bullet"
  gem "database_cleaner-active_record"
end

group :development do
  gem "annotaterb"
  gem "letter_opener"
  gem "web-console"
  gem "kamal", "~> 2.0", require: false
end

group :test do
  gem "shoulda-matchers"
  gem "webmock"
  gem "vcr"
  gem "timecop"
  gem "simplecov", require: false
  gem "rspec-sidekiq"
end
