# frozen_string_literal: true

class BaseClient
  class RateLimitExceeded < StandardError; end
  class CircuitOpenError < StandardError; end

  attr_reader :base_url, :rate_limit_key, :rate_limit_max, :rate_limit_period

  def initialize(base_url:, rate_limit_key: nil, rate_limit_max: 60, rate_limit_period: 60)
    @base_url = base_url
    @rate_limit_key = rate_limit_key
    @rate_limit_max = rate_limit_max
    @rate_limit_period = rate_limit_period
    @circuit_failures = 0
    @circuit_open_until = nil
  end

  private

  def connection
    @connection ||= Faraday.new(url: base_url) do |f|
      f.request :json
      f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                         exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed ]
      f.response :json
      f.response :raise_error
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
      count = redis.get(key).to_i
      raise RateLimitExceeded, "Rate limit exceeded for #{rate_limit_key}" if count >= rate_limit_max

      redis.multi do |tx|
        tx.incr(key)
        tx.expire(key, rate_limit_period)
      end
    end
  end

  def check_circuit!
    return unless @circuit_open_until
    return if Time.current > @circuit_open_until

    raise CircuitOpenError, "Circuit breaker open for #{self.class.name}"
  end

  def record_circuit_failure!
    @circuit_failures += 1
    @circuit_open_until = 30.seconds.from_now if @circuit_failures >= 5
  end

  def reset_circuit!
    @circuit_failures = 0
    @circuit_open_until = nil
  end
end
