# frozen_string_literal: true

REDIS_POOL = ConnectionPool.new(
  size: Integer(ENV.fetch("REDIS_POOL_SIZE", 10)),
  timeout: 3
) do
  Redis.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    driver: :hiredis,
    timeout: 2,
    reconnect_attempts: 1
  )
end

# Use RedisHelper.safe for optional Redis operations that must not crash the
# request when the server is briefly unreachable. Yields the connection and
# returns nil instead of raising on known transport failures.
module RedisHelper
  def self.safe
    REDIS_POOL.with { |conn| yield conn }
  rescue => e
    raise e unless connection_error?(e)

    Rails.logger.warn("[Redis] unavailable: #{e.class}: #{e.message}")
    nil
  end

  def self.connection_error?(error)
    return true if defined?(Redis::BaseConnectionError) && error.is_a?(Redis::BaseConnectionError)
    return true if defined?(RedisClient::CannotConnectError) && error.is_a?(RedisClient::CannotConnectError)
    return true if error.is_a?(Errno::ECONNREFUSED)
    return true if error.is_a?(Errno::ETIMEDOUT)
    return true if error.is_a?(IOError)

    false
  end
end
