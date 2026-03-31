# frozen_string_literal: true

class AlphaVantageClient < BaseClient
  STALE_TTL = 86_400 # Keep stale data for 24h beyond normal TTL

  def initialize
    super(
      api_name: "alpha_vantage",
      base_url: "https://www.alphavantage.co/query",
      rate_limit: ENV.fetch("ALPHA_VANTAGE_RATE_LIMIT_PER_DAY", 25).to_i,
      rate_period: 86_400
    )
  end

  def rsi(symbol, interval: "daily", period: 14)
    indicator_get("RSI", symbol, interval: interval, time_period: period, ttl: 1800)
  end

  def macd(symbol, interval: "daily")
    indicator_get("MACD", symbol, interval: interval, ttl: 1800)
  end

  def bollinger_bands(symbol, interval: "daily", period: 20)
    indicator_get("BBANDS", symbol, interval: interval, time_period: period, ttl: 1800)
  end

  def sma(symbol, interval: "daily", period: 50)
    indicator_get("SMA", symbol, interval: interval, time_period: period, ttl: 1800)
  end

  def ema(symbol, interval: "daily", period: 20)
    indicator_get("EMA", symbol, interval: interval, time_period: period, ttl: 1800)
  end

  def all_indicators(symbol)
    results = {}

    { rsi: -> { rsi(symbol) }, macd: -> { macd(symbol) }, bollinger_bands: -> { bollinger_bands(symbol) } }.each do |name, fetcher|
      results[name] = fetcher.call
    rescue RateLimitExceeded, ApiError => e
      Rails.logger.warn("[alpha_vantage] #{name} failed: #{e.message}, using stale cache")
      results[name] = stale_fallback_for(name, symbol)
    end

    results
  end

  private

  def indicator_get(function, symbol, interval: "daily", time_period: nil, ttl: 1800)
    params = {
      function: function,
      symbol: symbol,
      interval: interval,
      series_type: "close",
      apikey: api_key
    }
    params[:time_period] = time_period if time_period

    cached_get_with_stale_fallback(params, ttl: ttl)
  end

  def cached_get_with_stale_fallback(params, ttl: 1800)
    cache_key = build_cache_key("", params)
    stale_key = "#{cache_key}:stale"

    # Check fresh cache
    REDIS_POOL.with do |redis|
      cached = redis.get(cache_key)
      return JSON.parse(cached, symbolize_names: true) if cached
    end

    begin
      response = get("", params)

      # Store both fresh and stale copies
      REDIS_POOL.with do |redis|
        redis.setex(cache_key, ttl, response.to_json)
        redis.setex(stale_key, ttl + STALE_TTL, response.to_json)
      end

      response
    rescue RateLimitExceeded
      # Serve stale data when rate limited
      serve_stale(stale_key) || raise
    end
  end

  def serve_stale(stale_key)
    REDIS_POOL.with do |redis|
      stale = redis.get(stale_key)
      if stale
        parsed = JSON.parse(stale, symbolize_names: true)
        parsed.is_a?(Hash) ? parsed.merge(stale: true) : { data: parsed, stale: true }
      end
    end
  end

  def stale_fallback_for(indicator_name, symbol)
    params = case indicator_name
    when :rsi then { function: "RSI", symbol: symbol, interval: "daily", series_type: "close", apikey: api_key, time_period: 14 }
    when :macd then { function: "MACD", symbol: symbol, interval: "daily", series_type: "close", apikey: api_key }
    when :bollinger_bands then { function: "BBANDS", symbol: symbol, interval: "daily", series_type: "close", apikey: api_key, time_period: 20 }
    end

    stale_key = "#{build_cache_key('', params)}:stale"
    serve_stale(stale_key) || { error: true, message: "No cached data available for #{indicator_name}" }
  end

  def api_key
    ENV.fetch("ALPHA_VANTAGE_API_KEY", "")
  end
end
