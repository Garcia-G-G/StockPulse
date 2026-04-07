# frozen_string_literal: true

module Streaming
  class TradeAggregator
    def aggregate(trades)
      return nil if trades.nil? || trades.empty?

      total_volume = 0
      total_value = 0.0
      high = -Float::INFINITY
      low = Float::INFINITY

      trades.each do |trade|
        price = (trade["p"] || trade[:price]).to_f
        volume = (trade["v"] || trade[:volume] || 1).to_i

        total_volume += volume
        total_value += price * volume
        high = price if price > high
        low = price if price < low
      end

      last_trade = trades.last
      {
        price: (last_trade["p"] || last_trade[:price]).to_f,
        vwap: total_volume.positive? ? (total_value / total_volume).round(4) : 0,
        volume: total_volume,
        high: high,
        low: low,
        trade_count: trades.size,
        timestamp: Time.current.to_i
      }
    end
  end
end
