# frozen_string_literal: true

module Streaming
  class PriceStreamManager
    FLUSH_INTERVAL = 1     # aggregate trades every 1 second
    SNAPSHOT_INTERVAL = 60 # persist to DB every 60 seconds
    MAX_SYMBOLS = FinnhubConfig::MAX_WS_SYMBOLS
    RECONNECT_MAX = 60     # max backoff seconds

    def initialize
      @subscriptions = Concurrent::Set.new
      @running = Concurrent::AtomicBoolean.new(false)
      @trade_buffer = Concurrent::Map.new
      @cache = Streaming::RedisPriceCache.new
      @aggregator = Streaming::TradeAggregator.new
      @trades_count = Concurrent::AtomicFixnum.new(0)
      @ws = nil
      @reconnect_attempts = 0
      @started_at = nil
    end

    def start
      @running.make_true
      @started_at = Time.current
      @cache.set_connection_status("finnhub", "connecting")
      SystemLog.log(level: "info", component: "streaming", message: "PriceStreamManager starting (Finnhub)")

      symbols = Watchlists::Manager.new.all_watched_symbols
      symbols.first(MAX_SYMBOLS).each { |s| @subscriptions.add(s.upcase) }

      if defined?(EventMachine) && EventMachine.reactor_running?
        connect_websocket
      else
        # EventMachine not running — start it
        Thread.new do
          EM.run { connect_websocket }
        end
      end

      start_flush_loop
      start_snapshot_loop
      start_stats_loop

      # Keep main thread alive
      sleep(1) while @running.true?
    end

    def stop
      @running.make_false
      @ws&.close
      @ws = nil
      @subscriptions.clear
      @cache.set_connection_status("finnhub", "disconnected")
      EM.stop if defined?(EventMachine) && EM.reactor_running?
      SystemLog.log(level: "info", component: "streaming", message: "PriceStreamManager stopped")
    end

    def subscribe(symbol)
      symbol = symbol.upcase
      return if @subscriptions.size >= MAX_SYMBOLS

      @subscriptions.add(symbol)
      ws_subscribe(symbol) if @ws
    end

    def unsubscribe(symbol)
      symbol = symbol.upcase
      @subscriptions.delete(symbol)
      ws_unsubscribe(symbol) if @ws
    end

    def subscriptions
      @subscriptions.to_a
    end

    private

    # --- Finnhub WebSocket ---

    def connect_websocket
      url = "#{FinnhubConfig::WS_URL}?token=#{FinnhubConfig::API_KEY}"
      @ws = Faye::WebSocket::Client.new(url)

      @ws.on :open do |_event|
        @reconnect_attempts = 0
        @cache.set_connection_status("finnhub", "connected")
        SystemLog.log(level: "info", component: "streaming", message: "Finnhub WebSocket connected")

        # Subscribe all symbols
        @subscriptions.each { |sym| ws_subscribe(sym) }
      end

      @ws.on :message do |event|
        process_message(event.data)
      end

      @ws.on :close do |event|
        @ws = nil
        @cache.set_connection_status("finnhub", "disconnected")
        SystemLog.log(level: "warn", component: "streaming", message: "Finnhub WebSocket closed: #{event.code}")
        schedule_reconnect if @running.true?
      end

      @ws.on :error do |event|
        SystemLog.log(level: "error", component: "streaming", message: "Finnhub WebSocket error: #{event.message}")
      end
    end

    def schedule_reconnect
      @cache.set_connection_status("finnhub", "reconnecting")
      delay = [2**@reconnect_attempts, RECONNECT_MAX].min
      @reconnect_attempts += 1
      SystemLog.log(level: "info", component: "streaming", message: "Reconnecting in #{delay}s (attempt #{@reconnect_attempts})")

      if defined?(EventMachine) && EM.reactor_running?
        EM.add_timer(delay) { connect_websocket }
      else
        Thread.new { sleep(delay); start_polling_fallback }
      end
    end

    def ws_subscribe(symbol)
      return unless @ws

      @ws.send({ type: "subscribe", symbol: symbol }.to_json)
    end

    def ws_unsubscribe(symbol)
      return unless @ws

      @ws.send({ type: "unsubscribe", symbol: symbol }.to_json)
    end

    def process_message(raw)
      data = JSON.parse(raw)

      case data["type"]
      when "trade"
        (data["data"] || []).each do |trade|
          handle_trade({
            symbol: trade["s"],
            price: trade["p"].to_f,
            volume: trade["v"].to_i,
            timestamp: trade["t"].to_i / 1000,
            source: "finnhub"
          })
        end
      when "ping"
        @ws&.send({ type: "pong" }.to_json)
      end
    rescue JSON::ParserError => e
      SystemLog.log(level: "error", component: "streaming", message: "JSON parse error: #{e.message}")
    end

    # --- Trade Handling ---

    def handle_trade(normalized)
      symbol = normalized[:symbol]&.upcase
      return unless symbol && @subscriptions.include?(symbol)

      buffer = @trade_buffer.compute_if_absent(symbol) { Concurrent::Array.new }
      buffer << normalized
      @trades_count.increment
    end

    # --- Flush & Broadcast ---

    def start_flush_loop
      Thread.new do
        Thread.current.name = "stockpulse-flush"
        while @running.true?
          begin
            flush_trades
            sleep(FLUSH_INTERVAL)
          rescue StandardError => e
            SystemLog.log(level: "error", component: "streaming", message: "Flush loop error: #{e.message}")
            sleep(FLUSH_INTERVAL)
          end
        end
      end
    end

    def flush_trades
      @trade_buffer.each_pair do |symbol, trades|
        next if trades.empty?

        # Drain buffer atomically
        batch = []
        batch << trades.shift until trades.empty?
        next if batch.empty?

        aggregated = @aggregator.aggregate(batch)
        next unless aggregated

        price_data = build_price_data(symbol, aggregated, batch)
        @cache.store_price(symbol, price_data)
        @cache.push_history(symbol, price_data[:price])

        broadcast(symbol, price_data)
      end
    rescue StandardError => e
      SystemLog.log(level: "error", component: "streaming", message: "Flush error: #{e.message}")
    end

    def build_price_data(symbol, aggregated, batch)
      data = {
        symbol: symbol,
        price: aggregated[:price],
        change: 0,
        change_percent: 0,
        volume: aggregated[:volume],
        high: aggregated[:high],
        low: aggregated[:low],
        vwap: aggregated[:vwap],
        source: "finnhub",
        updated_at: Time.current.to_i
      }

      prev = @cache.get_price(symbol)
      if prev && prev["price"].to_f.positive?
        data[:change] = (data[:price] - prev["price"].to_f).round(4)
        data[:change_percent] = ((data[:change] / prev["price"].to_f) * 100).round(4)
      end

      data
    end

    def broadcast(symbol, price_data)
      cable_data = price_data.merge(
        c: price_data[:price],
        d: price_data[:change],
        dp: price_data[:change_percent],
        h: price_data[:high],
        l: price_data[:low],
        v: price_data[:volume]
      )

      ActionCable.server.broadcast("prices", cable_data)
      ActionCable.server.broadcast("prices:#{symbol}", cable_data.merge(
        history: @cache.get_history(symbol, 60)
      ))
    end

    # --- Polling Fallback (when WebSocket unavailable) ---

    def start_polling_fallback
      client = FinnhubClient.new
      while @running.true? && @ws.nil?
        @cache.set_connection_status("finnhub", "polling")
        @subscriptions.each do |symbol|
          begin
            quote = client.quote(symbol)
            handle_trade({
              symbol: symbol,
              price: quote["c"].to_f,
              volume: (quote["v"] || 0).to_i,
              timestamp: Time.current.to_i,
              source: "finnhub"
            })
          rescue BaseClient::RateLimitExceeded
            break
          rescue StandardError => e
            SystemLog.log(level: "debug", component: "streaming", message: "Poll error #{symbol}: #{e.message}")
          end
        end
        sleep(5)
      end
    end

    # --- DB Snapshots ---

    def start_snapshot_loop
      Thread.new do
        Thread.current.name = "stockpulse-snapshot"
        while @running.true?
          begin
            sleep(SNAPSHOT_INTERVAL)
            save_snapshots
          rescue StandardError => e
            SystemLog.log(level: "error", component: "streaming", message: "Snapshot loop error: #{e.message}")
            sleep(SNAPSHOT_INTERVAL)
          end
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
        SystemLog.log(level: "error", component: "streaming", message: "Snapshot failed #{symbol}: #{e.message}")
      end
    end

    # --- Stats ---

    def start_stats_loop
      Thread.new do
        Thread.current.name = "stockpulse-stats"
        while @running.true?
          @cache.update_stats({
            symbols_count: @subscriptions.size,
            trades_per_second: @trades_count.value,
            last_trade_at: Time.current.iso8601,
            uptime_seconds: @started_at ? (Time.current - @started_at).to_i : 0,
            finnhub_status: @cache.get_connection_status("finnhub")
          })
          @trades_count.value = 0
          sleep(10)
        end
      end
    end
  end
end
