# frozen_string_literal: true

class BaseClient
  class RateLimitExceeded < StandardError; end
  class CircuitOpen < StandardError; end
  class ApiError < StandardError; end

  CIRCUIT_FAILURE_THRESHOLD = 5
  CIRCUIT_RECOVERY_TIMEOUT = 30

  attr_reader :api_name, :base_url, :rate_limit, :rate_period

  def initialize(api_name:, base_url:, rate_limit:, rate_period: 60)
    raise NotImplementedError, "BaseClient cannot be instantiated directly" if instance_of?(BaseClient)

    @api_name = api_name
    @base_url = base_url
    @rate_limit = rate_limit
    @rate_period = rate_period
  end

  def remaining_calls
    REDIS_POOL.with do |redis|
      count = redis.get(rate_limit_key).to_i
      [ rate_limit - count, 0 ].max
    end
  end

  private

  def connection
    @connection ||= Faraday.new(url: base_url) do |f|
      f.request :json
      f.request :retry,
                max: 3,
                interval: 1,
                interval_randomness: 0.5,
                backoff_factor: 2,
                retry_statuses: [ 429, 500, 502, 503 ],
                retry_block: ->(env, _opts, retries, exc) {
                  Rails.logger.warn("[#{api_name}] Retry ##{retries} for #{env[:url]}: #{exc&.message}")
                }
      f.response :json, parser_options: { symbolize_names: true }
      f.response :raise_error
      f.adapter :typhoeus
    end
  end

  def get(path, params = {})
    check_rate_limit!
    check_circuit!

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = connection.get(path, params)
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)

    record_success!
    Rails.logger.info("[#{api_name}] GET #{path} => #{response.status} (#{elapsed}ms)")
    response.body
  rescue Faraday::TooManyRequestsError => e
    record_failure!
    raise RateLimitExceeded, "[#{api_name}] Rate limited by upstream: #{e.message}"
  rescue Faraday::Error => e
    record_failure!
    raise ApiError, "[#{api_name}] #{e.class}: #{e.message}"
  end

  def post(path, body = {})
    check_rate_limit!
    check_circuit!

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = connection.post(path, body)
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)

    record_success!
    Rails.logger.info("[#{api_name}] POST #{path} => #{response.status} (#{elapsed}ms)")
    response.body
  rescue Faraday::TooManyRequestsError => e
    record_failure!
    raise RateLimitExceeded, "[#{api_name}] Rate limited by upstream: #{e.message}"
  rescue Faraday::Error => e
    record_failure!
    raise ApiError, "[#{api_name}] #{e.class}: #{e.message}"
  end

  def cached_get(path, params = {}, ttl: 60)
    cache_key = build_cache_key(path, params)

    REDIS_POOL.with do |redis|
      cached = redis.get(cache_key)
      return JSON.parse(cached, symbolize_names: true) if cached
    end

    response = get(path, params)

    REDIS_POOL.with do |redis|
      redis.setex(cache_key, ttl, response.to_json)
    end

    response
  end

  # --- Rate Limiting (Token Bucket) ---

  def check_rate_limit!
    REDIS_POOL.with do |redis|
      count = redis.get(rate_limit_key).to_i
      raise RateLimitExceeded, "[#{api_name}] Rate limit exceeded (#{count}/#{rate_limit})" if count >= rate_limit

      redis.multi do |tx|
        tx.incr(rate_limit_key)
        tx.expire(rate_limit_key, rate_period)
      end
    end
  end

  def rate_limit_key
    "ratelimit:#{api_name}"
  end

  # --- Circuit Breaker (Redis-backed) ---

  def check_circuit!
    state = circuit_state
    case state
    when "open"
      if Time.current.to_f > circuit_opened_at + CIRCUIT_RECOVERY_TIMEOUT
        set_circuit_state!("half_open")
      else
        raise CircuitOpen, "[#{api_name}] Circuit breaker is open"
      end
    end
  end

  def record_success!
    REDIS_POOL.with do |redis|
      state = redis.get(circuit_state_key)
      if state == "half_open"
        redis.set(circuit_state_key, "closed")
        redis.del(circuit_failures_key)
      else
        redis.del(circuit_failures_key)
      end
    end
  end

  def record_failure!
    REDIS_POOL.with do |redis|
      failures = redis.incr(circuit_failures_key)
      redis.expire(circuit_failures_key, CIRCUIT_RECOVERY_TIMEOUT * 2)

      state = redis.get(circuit_state_key)
      if state == "half_open" || failures >= CIRCUIT_FAILURE_THRESHOLD
        redis.set(circuit_state_key, "open")
        redis.set(circuit_opened_at_key, Time.current.to_f.to_s)
      end
    end
  end

  def circuit_state
    REDIS_POOL.with { |r| r.get(circuit_state_key) || "closed" }
  end

  def circuit_opened_at
    REDIS_POOL.with { |r| r.get(circuit_opened_at_key).to_f }
  end

  def set_circuit_state!(state)
    REDIS_POOL.with { |r| r.set(circuit_state_key, state) }
  end

  def circuit_state_key
    "circuit:#{api_name}"
  end

  def circuit_failures_key
    "circuit:#{api_name}:failures"
  end

  def circuit_opened_at_key
    "circuit:#{api_name}:opened_at"
  end

  # --- Cache Helpers ---

  def build_cache_key(path, params)
    sorted = params.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}=#{v}" }.join("&")
    digest = Digest::MD5.hexdigest(sorted)
    "cache:#{api_name}:#{path}:#{digest}"
  end
end
