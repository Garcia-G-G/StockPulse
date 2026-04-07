# frozen_string_literal: true

class BaseClient
  class RateLimitExceeded < StandardError; end
  class CircuitOpenError < StandardError; end

  attr_reader :base_url, :rate_limit_key, :rate_limit_max, :rate_limit_period

  # Circuit breaker state is shared across all instances of a given client class,
  # stored in a class-level hash keyed by class name. This ensures the breaker
  # is effective even when new client instances are created per-request.
  CIRCUIT_STATE = Concurrent::Map.new

  def initialize(base_url:, rate_limit_key: nil, rate_limit_max: 60, rate_limit_period: 60)
    @base_url = base_url
    @rate_limit_key = rate_limit_key
    @rate_limit_max = rate_limit_max
    @rate_limit_period = rate_limit_period
  end

  private

  def connection
    @connection ||= Faraday.new(url: base_url) do |f|
      f.request :json
      f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                         exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
      f.response :raise_error  # Must be declared before :json so errors contain parsed bodies
      f.response :json
      f.options.timeout = 15
      f.options.open_timeout = 5
      f.adapter Faraday.default_adapter
    end
  end

  def get(path, params = {})
    check_circuit!
    check_rate_limit!
    response = connection.get(path, params)
    reset_circuit!
    response.body
  rescue Faraday::Error => e
    record_circuit_failure!
    raise e
  end

  def post(path, body = {})
    check_circuit!
    check_rate_limit!
    response = connection.post(path, body)
    reset_circuit!
    response.body
  rescue Faraday::Error => e
    record_circuit_failure!
    raise e
  end

  def check_rate_limit!
    return unless rate_limit_key

    REDIS_POOL.with do |redis|
      key = "rate_limit:#{rate_limit_key}"
      count = redis.incr(key)

      # Only set TTL when the key is first created (count == 1),
      # so the window doesn't keep extending on every request.
      redis.expire(key, rate_limit_period) if count == 1

      if count > rate_limit_max
        raise RateLimitExceeded, "Rate limit exceeded for #{rate_limit_key}"
      end
    end
  end

  def circuit_state
    CIRCUIT_STATE.compute_if_absent(self.class.name) { { failures: 0, open_until: nil } }
  end

  def check_circuit!
    state = circuit_state
    return unless state[:open_until]
    return if Time.current > state[:open_until]

    raise CircuitOpenError, "Circuit breaker open for #{self.class.name}"
  end

  def record_circuit_failure!
    state = circuit_state
    state[:failures] += 1
    state[:open_until] = 30.seconds.from_now if state[:failures] >= 5
  end

  def reset_circuit!
    state = circuit_state
    state[:failures] = 0
    state[:open_until] = nil
  end
end
