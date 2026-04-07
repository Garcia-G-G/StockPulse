# frozen_string_literal: true

module Streaming
  class PriceStreamManager
    FLUSH_INTERVAL = 1    # seconds
    SNAPSHOT_INTERVAL = 60 # seconds

    def initialize
      @subscriptions = Concurrent::Set.new
      @running = Concurrent::AtomicBoolean.new(false)
      @trade_buffer = Concurrent::Map.new
      @cache = Streaming::RedisPriceCache.new
      @aggregator = Streaming::TradeAggregator.new
      @alpaca_client = nil
      @finnhub_fallback_symbols = Concurrent::Set.new
      @trades_count = Concurrent::AtomicFixnum.new(0)
      @started_at = nil
    end

    def start
      @running.make_true
      @started_at = Time.current
      SystemLog.log(level: "info", component: "streaming", message: "PriceStreamManager starting (dual-source)")

      symbols = Watchlists::Manager.new.all_watched_symbols
      symbols.each { |s| @subscriptions.add(s.upcase) }

      connect_alpaca
      connect_finnhub_for_non_stocks
      start_flush_loop
      start_snapshot_loop
      start_stats_loop
    end

    def stop
      @running.make_false
      @alpaca_client&.disconnect
      @subscriptions.clear
      @cache.set_connection_status("alpaca", "disconnected")
      @cache.set_connection_status("finnhub", "disconnected")
      SystemLog.log(level: "info", component: "streaming", message: "PriceStreamManager stopped")
    end

    def subscribe(symbol)
      symbol = symbol.upcase
      @subscriptions.add(symbol)

      if stock_symbol?(symbol)
        if @alpaca_client&.connected?
          @alpaca_client.subscribe(symbol)
        else
          subscribe_finnhub_fallback(symbol)
        end
      else
        subscribe_finnhub(symbol)
      end
    end

    def unsubscribe(symbol)
      symbol = symbol.upcase
      @subscriptions.delete(symbol)
      @alpaca_client&.unsubscribe(symbol)
      @finnhub_fallback_symbols.delete(symbol)
    end

    def subscriptions
      @subscriptions.to_a
    end

    private

    # --- Source Connections ---

    def connect_alpaca
      return unless AlpacaConfig::API_KEY.present?

      @alpaca_client = AlpacaStreamClient.new(
        on_trade: method(:handle_trade),
        on_bar: method(:handle_bar),
        on_error: method(:handle_alpaca_error),
        on_status_change: method(:handle_alpaca_status_change)
      )

      if defined?(EventMachine) && EventMachine.reactor_running?
        @alpaca_client.connect
        # Subscribe stock symbols after connection is established
        EventMachine.add_timer(3) do
          stock_symbols = @subscriptions.select { |s| stock_symbol?(s) }.to_a
          @alpaca_client.subscribe(stock_symbols) if stock_symbols.any?
        end
      else
        SystemLog.log(level: "warn", component: "streaming", message: "EventMachine not running — using polling fallback for Alpaca")
        start_polling_fallback
      end
    end

    def connect_finnhub_for_non_stocks
      non_stock = @subscriptions.reject { |s| stock_symbol?(s) }.to_a
      non_stock.each { |s| subscribe_finnhub(s) }
    end

    def subscribe_finnhub(symbol)
      # Finnhub subscription via polling (REST)
      @finnhub_fallback_symbols.add(symbol)
    end

    def subscribe_finnhub_fallback(symbol)
      @finnhub_fallback_symbols.add(symbol)
      SystemLog.log(level: "info", component: "streaming", message: "Failover: #{symbol} moved to finnhub (polling)")
    end

    # --- Symbol Routing ---

    def stock_symbol?(symbol)
      !symbol.include?("/") && !symbol.start_with?("CRYPTO:")
    end

    def route_symbol(symbol)
      return :finnhub unless stock_symbol?(symbol)
      @alpaca_client&.connected? ? :alpaca : :finnhub
    end

    # --- Trade Handling ---

    def handle_trade(normalized)
      symbol = normalized[:symbol]
      return unless symbol && @subscriptions.include?(symbol.upcase)

      buffer = @trade_buffer.compute_if_absent(symbol.upcase) { [] }
      buffer << normalized
      @trades_count.increment
    end

    def handle_bar(normalized)
      symbol = normalized[:symbol]&.upcase
      return unless symbol

      @cache.store_bar(symbol, normalized)
    end

    def handle_alpaca_error(message)
      SystemLog.log(level: "error", component: "streaming", message: "Alpaca error: #{message}")
    end

    def handle_alpaca_status_change(old_status, new_status)
      if new_status == :disconnected && old_status == :connected
        # Failover: move all stock symbols to Finnhub polling
        stock_symbols = @subscriptions.select { |s| stock_symbol?(s) }
        stock_symbols.each { |s| subscribe_finnhub_fallback(s) }
        SystemLog.log(level: "warn", component: "streaming", message: "Alpaca down — #{stock_symbols.size} symbols failed over to Finnhub")
      elsif new_status == :connected && old_status != :connected
        # Recover: move stock symbols back to Alpaca
        stock_symbols = @subscriptions.select { |s| stock_symbol?(s) }.to_a
        @finnhub_fallback_symbols.subtract(stock_symbols)
        @alpaca_client.subscribe(stock_symbols)
        SystemLog.log(level: "info", component: "streaming", message: "Alpaca recovered — #{stock_symbols.size} symbols restored")
      end
    end

    # --- Flush & Broadcast ---

    def start_flush_loop
      Thread.new do
        while @running.true?
          flush_trades
          sleep(FLUSH_INTERVAL)
        end
      end
    end

    def flush_trades
      @trade_buffer.each_pair do |symbol, trades|
        next if trades.empty?

        # Drain buffer
        batch = trades.dup
        trades.clear

        aggregated = @aggregator.aggregate(batch)
        next unless aggregated

        # Store in Redis
        price_data = {
          symbol: symbol,
          price: aggregated[:price],
          change: 0,
          change_percent: 0,
          volume: aggregated[:volume],
          high: aggregated[:high],
          low: aggregated[:low],
          vwap: aggregated[:vwap],
          source: batch.first&.dig(:source) || "unknown",
          updated_at: Time.current.to_i
        }

        # Calculate change from previous
        prev = @cache.get_price(symbol)
        if prev && prev["price"]
          price_data[:change] = (price_data[:price] - prev["price"].to_f).round(4)
          price_data[:change_percent] = prev["price"].to_f.positive? ? ((price_data[:change] / prev["price"].to_f) * 100).round(4) : 0
        end

        @cache.store_price(symbol, price_data)
        @cache.push_history(symbol, price_data[:price])

        # Broadcast via ActionCable
        broadcast_data = price_data.merge(
          c: price_data[:price],
          d: price_data[:change],
          dp: price_data[:change_percent],
          h: price_data[:high],
          l: price_data[:low],
          v: price_data[:volume]
        )

        ActionCable.server.broadcast("prices", broadcast_data)
        ActionCable.server.broadcast("prices:#{symbol}", broadcast_data.merge(
          history: @cache.get_history(symbol, 60)
        ))
      end
    rescue StandardError => e
      SystemLog.log(level: "error", component: "streaming", message: "Flush error: #{e.message}")
    end

    # --- Polling Fallback ---

    def start_polling_fallback
      Thread.new do
        client = FinnhubClient.new
        while @running.true?
          symbols_to_poll = @finnhub_fallback_symbols.to_a + @subscriptions.to_a
          symbols_to_poll.uniq.each do |symbol|
            begin
              quote = client.quote(symbol)
              handle_trade({
                symbol: symbol,
                price: quote["c"].to_f,
                volume: quote["v"].to_i,
                timestamp: Time.current.to_i,
                source: "finnhub"
              })
            rescue BaseClient::RateLimitExceeded
              break
            rescue StandardError => e
              SystemLog.log(level: "debug", component: "streaming", message: "Poll failed for #{symbol}: #{e.message}")
            end
          end
          sleep(5)
        end
      end
    end

    # --- Snapshots (DB persistence) ---

    def start_snapshot_loop
      Thread.new do
        while @running.true?
          sleep(SNAPSHOT_INTERVAL)
          save_snapshots
        end
      end
    end

    def save_snapshots
      @subscriptions.each do |symbol|
        cached = @cache.get_price(symbol)
        next unless cached && cached["price"]

        PriceSnapshot.create!(
          symbol: symbol,
          price: cached["price"],
          volume: cached["volume"],
          high: cached["high"],
          low: cached["low"],
          change_percent: cached["change_percent"],
          captured_at: Time.current,
          data: cached
        )
      rescue StandardError => e
        SystemLog.log(level: "error", component: "streaming", message: "Snapshot save failed for #{symbol}: #{e.message}")
      end
    end

    # --- Stats ---

    def start_stats_loop
      Thread.new do
        while @running.true?
          @cache.update_stats({
            symbols_count: @subscriptions.size,
            trades_per_second: @trades_count.value,
            last_trade_at: Time.current.iso8601,
            uptime_seconds: (Time.current - @started_at).to_i,
            alpaca_status: @alpaca_client&.status&.to_s || "not_configured",
            finnhub_fallback_count: @finnhub_fallback_symbols.size
          })
          @trades_count.value = 0
          sleep(10)
        end
      end
    end
  end
end
