# frozen_string_literal: true

class PriceSnapshotJob < ApplicationJob
  queue_as :default

  STALENESS_THRESHOLD = 5.minutes

  def perform(symbol:, open_price:, high_price:, low_price:, close_price:, volume:, vwap:, change_percent:, timestamp:, interval: "1m")
    ts = Time.zone.parse(timestamp)

    if ts < STALENESS_THRESHOLD.ago
      Rails.logger.debug("[PriceSnapshotJob] Skipping stale snapshot for #{symbol} at #{timestamp}")
      return
    end

    PriceSnapshot.find_or_create_by!(symbol: symbol, timestamp: ts, interval: interval) do |snap|
      snap.open_price = open_price
      snap.high_price = high_price
      snap.low_price = low_price
      snap.close_price = close_price
      snap.volume = volume
      snap.vwap = vwap
      snap.change_percent = change_percent
      snap.source = "finnhub"
    end
  end
end
