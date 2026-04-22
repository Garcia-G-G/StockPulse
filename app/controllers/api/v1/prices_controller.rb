# frozen_string_literal: true

module Api
  module V1
    class PricesController < BaseController
      skip_before_action :authenticate_user_or_api!, raise: false

      def current
        symbols = params[:symbols]&.split(",")&.map(&:strip)&.map(&:upcase)&.reject(&:blank?)
        return render json: { error: "symbols parameter required" }, status: :bad_request unless symbols&.any?

        # Limit the number of symbols per request to prevent abuse
        symbols = symbols.first(50)

        cache = Streaming::RedisPriceCache.new
        cached = cache.get_prices(symbols) # single MGET round-trip

        # Parallel-fetch the cache misses in one batch.
        missing = cached.select { |_, v| v.nil? }.keys
        if missing.any?
          quotes = ParallelQuoteFetcher.new.fetch(missing)
          now = Time.current.to_i
          quotes.each do |sym, data|
            cached[sym] = {
              "symbol" => sym,
              "price" => data[:price],
              "change" => data[:change],
              "change_percent" => data[:change_percent],
              "high" => data[:high],
              "low" => data[:low],
              "source" => "finnhub_rest",
              "updated_at" => now
            }
            cache.store_price(sym, cached[sym])
          end
        end

        render json: { data: cached.compact }
      end

      def history
        symbol = params[:id].upcase
        limit = (params[:limit] || 60).to_i.clamp(1, 500)
        interval = params[:interval] || "1m"

        cache = Streaming::RedisPriceCache.new

        if interval == "1m" && limit <= 60
          # Recent data from Redis
          history = cache.get_history(symbol, limit)
          render json: { symbol: symbol, interval: interval, data: history }
        else
          # Historical data from DB
          snapshots = PriceSnapshot.for_symbol(symbol)
                                   .recent
                                   .limit(limit)
                                   .pluck(:captured_at, :open, :high, :low, :price, :volume)
                                   .map do |row|
            { timestamp: row[0]&.iso8601, open: row[1], high: row[2], low: row[3], close: row[4], volume: row[5] }
          end
          render json: { symbol: symbol, interval: interval, data: snapshots }
        end
      end

      def stream_status
        cache = Streaming::RedisPriceCache.new
        stats = cache.get_stats

        render json: {
          finnhub: cache.get_connection_status("finnhub"),
          symbols_active: stats["symbols_count"] || 0,
          trades_per_second: stats["trades_per_second"] || 0,
          uptime_seconds: stats["uptime_seconds"] || 0,
          last_trade_at: stats["last_trade_at"]
        }
      end
    end
  end
end
