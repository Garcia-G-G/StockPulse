# frozen_string_literal: true

module Api
  module V1
    class AnalysisController < BaseController
      def overview
        symbol = params[:id].upcase
        quote = FinnhubClient.new.quote(symbol)
        indicators = cached_indicators(symbol)

        ai_analysis = begin
          AiServiceClient.new.analyze(
            symbol: symbol,
            price_data: quote,
            technical_data: indicators,
            news_data: nil
          )
        rescue StandardError => e
          Rails.logger.warn("[AnalysisController] AI service unavailable for #{symbol}: #{e.message}")
          nil
        end

        render json: {
          symbol: symbol,
          quote: quote,
          indicators: indicators,
          ai_analysis: ai_analysis
        }
      end

      def technical
        symbol = params[:id].upcase
        indicators = cached_indicators(symbol)

        if indicators.blank?
          client = AlphaVantageClient.new
          indicators = {
            rsi: client.rsi(symbol),
            macd: client.macd(symbol),
            bollinger: client.bollinger_bands(symbol)
          }
          cache_indicators(symbol, indicators)
        end

        render json: { symbol: symbol, indicators: indicators }
      end

      def news
        symbol = params[:id].upcase
        news_data = MarketAuxClient.new.news(symbols: [symbol], limit: 10)

        render json: { symbol: symbol, news: news_data }
      end

      def briefing
        symbols = current_user.watchlist_items.active.pluck(:symbol)
        client = FinnhubClient.new

        quotes = symbols.first(10).filter_map do |sym|
          quote = client.quote(sym)
          { symbol: sym, **quote }
        rescue BaseClient::RateLimitExceeded
          break # Stop fetching when rate limited
        rescue StandardError => e
          Rails.logger.debug("[Briefing] Quote fetch failed for #{sym}: #{e.message}")
          nil
        end

        render json: {
          date: Date.today,
          watchlist_summary: quotes,
          active_alerts: current_user.alerts.active.count,
          alerts_today: current_user.alert_histories.today.count
        }
      end

      private

      def cached_indicators(symbol)
        REDIS_POOL.with do |redis|
          cached = redis.get("indicators:#{symbol}")
          cached ? JSON.parse(cached) : nil
        end
      end

      def cache_indicators(symbol, data)
        REDIS_POOL.with do |redis|
          redis.set("indicators:#{symbol}", data.to_json, ex: 3600)
        end
      end
    end
  end
end
