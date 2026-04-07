# frozen_string_literal: true

class PriceSnapshotJob < ApplicationJob
  queue_as :default

  def perform(symbol)
    client = FinnhubClient.new
    quote = client.quote(symbol)

    PriceSnapshot.create!(
      symbol: symbol.upcase,
      price: quote["c"],
      open: quote["o"],
      high: quote["h"],
      low: quote["l"],
      volume: quote["v"] || 0,
      change_percent: quote["dp"],
      captured_at: Time.current,
      data: quote
    )

    engine = Alerts::Engine.new
    results = engine.evaluate_all(symbol: symbol, price_data: quote)

    results.each do |result|
      alert = result[:alert]
      AlertHistory.create!(
        alert: alert,
        user: alert.user,
        symbol: alert.symbol,
        alert_type: alert.alert_type,
        message: result[:message],
        data: result[:data],
        channels_notified: alert.user.notification_channels,
        triggered_at: Time.current
      )

      SendNotificationJob.perform_later(user_id: alert.user_id, message: result[:message])
    end

    PricesChannel.broadcast_price(symbol, quote)
  rescue BaseClient::RateLimitExceeded => e
    SystemLog.log(level: "warn", component: "price_snapshot", message: "Rate limited for #{symbol}: #{e.message}")
  rescue StandardError => e
    SystemLog.log(level: "error", component: "price_snapshot", message: "Failed for #{symbol}: #{e.message}", data: { backtrace: e.backtrace&.first(5) })
    raise
  end
end
