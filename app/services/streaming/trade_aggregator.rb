# frozen_string_literal: true

module Streaming
  class TradeAggregator
    attr_reader :trades

    def initialize
      @trades = Concurrent::Array.new
      @mutex = Mutex.new
    end

    def add_trade(symbol:, price:, volume:, timestamp:)
      @trades << { symbol: symbol, price: price.to_f, volume: volume.to_f, timestamp: timestamp }
    end

    def aggregate(symbol)
      symbol_trades = @trades.select { |t| t[:symbol] == symbol }
      return nil if symbol_trades.empty?

      prices = symbol_trades.map { |t| t[:price] }
      volumes = symbol_trades.map { |t| t[:volume] }
      total_volume = volumes.sum

      {
        symbol: symbol,
        vwap: total_volume > 0 ? symbol_trades.sum { |t| t[:price] * t[:volume] } / total_volume : prices.last,
        high: prices.max,
        low: prices.min,
        last: prices.last,
        volume: total_volume,
        trade_count: symbol_trades.size
      }
    end

    def flush(symbol)
      @trades.reject! { |t| t[:symbol] == symbol }
    end

    def flush_all
      @trades.clear
    end
  end
end
