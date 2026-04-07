# frozen_string_literal: true

module Streaming
  class RedisPriceCache
    PRICE_TTL = 300      # 5 minutes
    BAR_TTL = 120        # 2 minutes
    HISTORY_SIZE = 60    # 1 minute of 1-second samples

    def store_price(symbol, data)
      REDIS_POOL.with do |redis|
        redis.setex("price:current:#{symbol}", PRICE_TTL, data.to_json)
      end
    end

    def get_price(symbol)
      REDIS_POOL.with do |redis|
        raw = redis.get("price:current:#{symbol}")
        raw ? JSON.parse(raw) : nil
      end
    end

    def get_prices(symbols)
      REDIS_POOL.with do |redis|
        keys = symbols.map { |s| "price:current:#{s}" }
        values = redis.mget(*keys)
        symbols.zip(values).each_with_object({}) do |(sym, val), hash|
          hash[sym] = val ? JSON.parse(val) : nil
        end
      end
    end

    def store_bar(symbol, data)
      REDIS_POOL.with do |redis|
        redis.setex("price:bar:#{symbol}", BAR_TTL, data.to_json)
      end
    end

    def get_bar(symbol)
      REDIS_POOL.with do |redis|
        raw = redis.get("price:bar:#{symbol}")
        raw ? JSON.parse(raw) : nil
      end
    end

    def push_history(symbol, price)
      REDIS_POOL.with do |redis|
        key = "price:history:#{symbol}"
        redis.lpush(key, price.to_f)
        redis.ltrim(key, 0, HISTORY_SIZE - 1)
        redis.expire(key, PRICE_TTL)
      end
    end

    def get_history(symbol, count = HISTORY_SIZE)
      REDIS_POOL.with do |redis|
        redis.lrange("price:history:#{symbol}", 0, count - 1).map(&:to_f)
      end
    end

    def set_connection_status(source, status)
      REDIS_POOL.with do |redis|
        redis.set("stream:status:#{source}", status.to_s)
      end
    end

    def get_connection_status(source)
      REDIS_POOL.with do |redis|
        redis.get("stream:status:#{source}") || "unknown"
      end
    end

    def update_stats(stats)
      REDIS_POOL.with do |redis|
        redis.set("stream:stats", stats.to_json)
      end
    end

    def get_stats
      REDIS_POOL.with do |redis|
        raw = redis.get("stream:stats")
        raw ? JSON.parse(raw) : {}
      end
    end
  end
end
