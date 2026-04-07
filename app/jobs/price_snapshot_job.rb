# frozen_string_literal: true

class PriceSnapshotJob < ApplicationJob
  queue_as :default

  def perform(symbol)
    symbol = symbol.upcase
    client = FinnhubClient.new
    quote = client.quote(symbol)

    return if quote.nil? || quote["c"].to_f.zero?

    PriceSnapshot.create!(
      symbol: symbol,
      price: quote["c"],
      open: quote["o"],
      high: quote["h"],
      low: quote["l"],
      volume: quote["v"] || 0,
      change_percent: quote["dp"],
      captured_at: Time.current,
      data: quote
    )

    # Delegate alert evaluation to the dedicated job to avoid duplicated logic
    EvaluateAlertsJob.perform_later(symbol: symbol, price_data: quote)

    PricesChannel.broadcast_price(symbol, quote)
  rescue BaseClient::RateLimitExceeded => e
    SystemLog.log(level: "warn", component: "price_snapshot", message: "Rate limited for #{symbol}: #{e.message}")
  rescue StandardError => e
    SystemLog.log(level: "error", component: "price_snapshot", message: "Failed for #{symbol}: #{e.message}", data: { backtrace: e.backtrace&.first(5) })
    raise
  end
end
