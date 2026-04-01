# frozen_string_literal: true

module Streaming
  class TradeAggregator
    FLUSH_INTERVAL = 1 # seconds

    def initialize
      @windows = {}
      @previous_closes = {}
      @mutex = Mutex.new
      @running = false
      @flush_thread = nil
    end

    def start
      @running = true
      start_flush_thread
      Rails.logger.info("[TradeAggregator] Started")
    end

    def stop
      @running = false
      @flush_thread&.join(5)
      flush_all_windows
      Rails.logger.info("[TradeAggregator] Stopped")
    end

    def process_trades(trades)
      trades.each { |trade| process_tick(trade) }
    end

    private

    def process_tick(trade)
      symbol = trade[:s]
      price = trade[:p].to_f
      volume = trade[:v].to_f
      timestamp = trade[:t] ? Time.at(trade[:t] / 1000.0) : Time.current

      @mutex.synchronize do
        window = @windows[symbol] ||= new_window(symbol, price, timestamp)

        # If this trade belongs to a new second, flush the old window first
        if timestamp.to_i > window[:window_start].to_i
          flush_window(symbol, window)
          @windows[symbol] = new_window(symbol, price, timestamp)
          window = @windows[symbol]
        end

        window[:high] = price if price > window[:high]
        window[:low] = price if price < window[:low]
        window[:close] = price
        window[:volume] += volume
        window[:vwap_numerator] += price * volume
        window[:vwap_denominator] += volume
        window[:trade_count] += 1
      end
    end

    def new_window(symbol, price, timestamp)
      {
        symbol: symbol,
        open: price,
        high: price,
        low: price,
        close: price,
        volume: 0.0,
        vwap_numerator: 0.0,
        vwap_denominator: 0.0,
        trade_count: 0,
        window_start: Time.at(timestamp.to_i)
      }
    end

    # --- Flush ---

    def start_flush_thread
      @flush_thread = Thread.new do
        while @running
          sleep FLUSH_INTERVAL
          flush_all_windows
        end
      rescue StandardError => e
        Rails.logger.error("[TradeAggregator] Flush thread error: #{e.message}")
        retry if @running
      end
    end

    def flush_all_windows
      windows_to_flush = nil

      @mutex.synchronize do
        cutoff = Time.at(Time.current.to_i - 1)
        windows_to_flush = @windows.select { |_, w| w[:window_start] <= cutoff }
        windows_to_flush.each_key { |sym| @windows.delete(sym) }
      end

      windows_to_flush&.each { |symbol, window| flush_window(symbol, window) }
    end

    def flush_window(symbol, window)
      return if window[:trade_count].zero?

      vwap = window[:vwap_denominator] > 0 ? (window[:vwap_numerator] / window[:vwap_denominator]).round(4) : window[:close]

      previous_close = @previous_closes[symbol]
      change = previous_close ? (window[:close] - previous_close).round(4) : nil
      change_percent = previous_close && previous_close > 0 ? ((change / previous_close) * 100).round(4) : nil

      @previous_closes[symbol] = window[:close]

      payload = {
        symbol: symbol,
        price: window[:close],
        open: window[:open],
        high: window[:high],
        low: window[:low],
        change: change,
        change_percent: change_percent,
        volume: window[:volume],
        vwap: vwap,
        trade_count: window[:trade_count],
        timestamp: window[:window_start].iso8601,
        source: "websocket"
      }

      broadcast(symbol, payload)
      publish_to_redis(symbol, payload)
      evaluate_alerts(symbol, payload)
      enqueue_snapshot(symbol, window, vwap, change_percent)
    rescue StandardError => e
      Rails.logger.error("[TradeAggregator] Flush error for #{symbol}: #{e.message}")
    end

    # --- Broadcast via ActionCable ---

    def broadcast(symbol, payload)
      PricesChannel.broadcast_price(symbol, payload)
    end

    # --- Publish to Redis pub/sub ---

    def publish_to_redis(symbol, payload)
      REDIS_POOL.with do |redis|
        redis.publish("prices:#{symbol}", payload.to_json)
        redis.publish("prices:all", payload.to_json)
      end
    end

    # --- Alert Evaluation ---

    def evaluate_alerts(_symbol, payload)
      Alerts::Engine.new.evaluate(payload)
    rescue StandardError => e
      Rails.logger.error("[TradeAggregator] Alert evaluation error for #{symbol}: #{e.message}")
    end

    # --- Snapshot Persistence ---

    def enqueue_snapshot(symbol, window, vwap, change_percent)
      PriceSnapshotJob.perform_later(
        symbol: symbol,
        open_price: window[:open],
        high_price: window[:high],
        low_price: window[:low],
        close_price: window[:close],
        volume: window[:volume].to_i,
        vwap: vwap,
        change_percent: change_percent,
        timestamp: window[:window_start].iso8601,
        interval: "1m"
      )
    end
  end
end
