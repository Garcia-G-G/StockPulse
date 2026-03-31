REDIS_POOL = ConnectionPool.new(size: 25, timeout: 5) do
  Redis.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    driver: :hiredis
  )
end
