# frozen_string_literal: true

# Parse CORS origins from environment variable with sensible defaults based on environment
cors_origins = if Rails.env.development?
                  ENV.fetch("CORS_ORIGINS", "http://localhost:3000,http://localhost:3001").split(",").map(&:strip)
                else
                  ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
                end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*cors_origins) if cors_origins.any?

    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: true,
      max_age: 600
  end
end
