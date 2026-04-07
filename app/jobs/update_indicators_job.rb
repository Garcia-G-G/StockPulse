# frozen_string_literal: true

class UpdateIndicatorsJob < ApplicationJob
  queue_as :default

  def perform
    symbols = Watchlists::Manager.new.all_watched_symbols
    client = AlphaVantageClient.new

    symbols.each do |symbol|
      cache_key = "indicators:#{symbol}"

      REDIS_POOL.with do |redis|
        cached = redis.get(cache_key)
        next if cached.present?

        data = {}
        begin
          data[:rsi] = client.rsi(symbol)
        rescue StandardError => e
          SystemLog.log(level: "warn", component: "indicators", message: "RSI fetch failed for #{symbol}: #{e.message}")
        end
        begin
          data[:macd] = client.macd(symbol)
        rescue StandardError => e
          SystemLog.log(level: "warn", component: "indicators", message: "MACD fetch failed for #{symbol}: #{e.message}")
        end
        begin
          data[:bollinger] = client.bollinger_bands(symbol)
        rescue StandardError => e
          SystemLog.log(level: "warn", component: "indicators", message: "Bollinger fetch failed for #{symbol}: #{e.message}")
        end

        # Only cache and evaluate if we got at least some data
        next if data.values.all?(&:nil?)

        redis.set(cache_key, data.to_json, ex: 3600)

        evaluate_technical_alerts(symbol, data)
      end
    rescue BaseClient::RateLimitExceeded
      SystemLog.log(level: "warn", component: "indicators", message: "Rate limited, stopping indicator updates")
      break
    rescue StandardError => e
      SystemLog.log(level: "error", component: "indicators", message: "Failed for #{symbol}: #{e.message}")
    end
  end

  private

  def evaluate_technical_alerts(symbol, technical_data)
    latest_snapshot = PriceSnapshot.for_symbol(symbol).recent.first
    return unless latest_snapshot

    price_data = { price: latest_snapshot.price, volume: latest_snapshot.volume }
    results = Alerts::Engine.new.evaluate_all(
      symbol: symbol, price_data: price_data, technical_data: technical_data,
      alert_types: Alerts::Engine::TECHNICAL_TYPES
    )

    results.each do |result|
      alert = result[:alert]
      AlertHistory.create!(
        alert: alert, user: alert.user, symbol: symbol,
        alert_type: alert.alert_type, message: result[:message],
        data: result[:data], channels_notified: alert.user.notification_channels,
        triggered_at: Time.current
      )
      SendNotificationJob.perform_later(user_id: alert.user_id, message: result[:message])
    end
  end
end
