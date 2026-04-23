# frozen_string_literal: true

# Safelist localhost in development
Rack::Attack.safelist("allow from localhost") do |req|
  req.ip == "127.0.0.1" || req.ip == "::1" if Rails.env.development?
end

# Rate limit API endpoints: 60 requests per minute
Rack::Attack.throttle("api/ip", limit: 60, period: 60.seconds) do |req|
  req.ip if req.path.start_with?("/api/")
end

# Aggressive rate limit for notification test endpoint: 5 requests per minute
Rack::Attack.throttle("notification_test/ip", limit: 5, period: 60.seconds) do |req|
  req.ip if req.path.include?("/notification_test") || req.path.include?("/notifications/test")
end

# Custom response handler for throttled requests (renamed in newer rack-attack).
Rack::Attack.throttled_responder = lambda { |req|
  match_data = req.env["rack.attack.match_data"]
  now = Time.now.utc

  headers = {
    "X-RateLimit-Limit" => match_data[:limit].to_s,
    "X-RateLimit-Remaining" => "0",
    "X-RateLimit-Reset" => (now + match_data[:period]).to_i.to_s,
    "Retry-After" => match_data[:period].to_s
  }

  [
    429,
    headers,
    [
      {
        error: "Rate limit exceeded",
        message: "Too many requests. Please try again later.",
        retry_after: match_data[:period]
      }.to_json
    ]
  ]
}
