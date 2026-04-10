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
        cached = cache.get_prices(symbols)

        # Fill missing from Finnhub REST
        missing = cached.select { |_, v| v.nil? }.keys
        if missing.any?
          client = FinnhubClient.new
          missing.each do |sym|
            begin
              quote = client.quote(sym)
              next if quote.nil? || quote["c"].to_f.zero?

              cached[sym] = {
                "symbol" => sym,
                "price" => quote["c"],
                "change" => quote["d"],
                "change_percent" => quote["dp"],
                "volume" => quote["v"],
                "high" => quote["h"],
                "low" => quote["l"],
                "source" => "finnhub_rest",
                "updated_at" => Time.current.to_i
              }
              cache.store_price(sym, cached[sym])
            rescue BaseClient::RateLimitExceeded
              break
            rescue StandardError => e
              Rails.logger.debug("[PricesController] Quote fetch failed for #{sym}: #{e.message}")
              next
            end
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
