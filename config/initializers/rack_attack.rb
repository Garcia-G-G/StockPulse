Rack::Attack.throttle("api/ip", limit: 100, period: 60.seconds) do |req|
  req.ip if req.path.start_with?("/api/")
end

Rack::Attack.throttle("api/aggressive", limit: 10, period: 10.seconds) do |req|
  req.ip if req.path.include?("/analysis/")
end
