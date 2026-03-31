# frozen_string_literal: true

require "faye/websocket"
require "eventmachine"

module Streaming
  class PriceStreamManager
    MAX_SLOTS = 50
    HEARTBEAT_INTERVAL = 30
    HEARTBEAT_TIMEOUT = 10
    MAX_BACKOFF = 60
    REST_POLL_INTERVAL = 60

    US_HOLIDAYS_2026 = %w[
      2026-01-01 2026-01-19 2026-02-16 2026-04-03 2026-05-25
      2026-07-03 2026-09-07 2026-11-26 2026-12-25
    ].freeze

    attr_reader :aggregator

    def initialize
      @aggregator = TradeAggregator.new
      @subscriptions = Set.new
      @running = false
      @backoff = 1
      @mutex = Mutex.new
      @ws = nil
      set_status("disconnected")
    end

    def start
      @running = true
      setup_signal_handlers

      Rails.logger.info("[PriceStreamManager] Starting streaming process")

      loop do
        break unless @running

        if market_open?
          run_websocket_loop
        else
          Rails.logger.info("[PriceStreamManager] Market closed, falling back to REST polling")
          run_rest_polling_loop
        end

        break unless @running

        sleep 10
      end

      Rails.logger.info("[PriceStreamManager] Streaming process stopped")
    end

    def stop
      @running = false
      set_status("disconnected")
      @ws&.close
      @aggregator.stop
      Rails.logger.info("[PriceStreamManager] Graceful shutdown initiated")
    end

    def subscribe(symbol)
      @mutex.synchronize do
        return if @subscriptions.include?(symbol)
        return unless @subscriptions.size < MAX_SLOTS

        send_subscribe(symbol)
        @subscriptions.add(symbol)
        persist_subscriptions
      end
    end

    def unsubscribe(symbol)
      @mutex.synchronize do
        return unless @subscriptions.include?(symbol)

        send_unsubscribe(symbol)
        @subscriptions.delete(symbol)
        persist_subscriptions
      end
    end

    def rebalance_slots!
      desired = prioritized_symbols.first(MAX_SLOTS)
      current = @subscriptions.to_a

      to_remove = current - desired
      to_add = desired - current

      to_remove.each { |sym| unsubscribe(sym) }
      to_add.each { |sym| subscribe(sym) }

      Rails.logger.info("[PriceStreamManager] Rebalanced: +#{to_add.size} -#{to_remove.size}, active: #{@subscriptions.size}")
    end

    def market_open?
      et = Time.current.in_time_zone("Eastern Time (US & Canada)")
      return false unless (1..5).cover?(et.wday)
      return false if US_HOLIDAYS_2026.include?(et.strftime("%Y-%m-%d"))

      market_open = et.change(hour: 9, min: 30)
      market_close = et.change(hour: 16, min: 0)
      et.between?(market_open, market_close)
    end

    private

    # --- WebSocket Loop ---

    def run_websocket_loop
      EM.run do
        connect_websocket

        start_heartbeat_thread
        start_command_listener_thread

        EM.add_periodic_timer(1) do
          unless @running
            EM.stop
            break
          end
        end
      end
    end

    def connect_websocket
      url = "wss://ws.finnhub.io?token=#{ENV.fetch('FINNHUB_API_KEY', '')}"
      @ws = Faye::WebSocket::Client.new(url)

      @ws.on :open do |_event|
        Rails.logger.info("[PriceStreamManager] WebSocket connected")
        set_status("connected")
        @backoff = 1
        update_heartbeat

        rebalance_slots!
        @aggregator.start
      end

      @ws.on :message do |event|
        update_heartbeat
        process_message(event.data)
      end

      @ws.on :close do |event|
        Rails.logger.warn("[PriceStreamManager] WebSocket closed: code=#{event.code} reason=#{event.reason}")
        set_status("disconnected")
        @aggregator.stop

        if @running
          schedule_reconnect
        else
          EM.stop
        end
      end

      @ws.on :error do |event|
        Rails.logger.error("[PriceStreamManager] WebSocket error: #{event.message}")
      end
    end

    def schedule_reconnect
      set_status("reconnecting")
      delay = @backoff
      Rails.logger.info("[PriceStreamManager] Reconnecting in #{delay}s (backoff)")
      @backoff = [ @backoff * 2, MAX_BACKOFF ].min

      EM.add_timer(delay) { connect_websocket }
    end

    def process_message(raw)
      data = JSON.parse(raw, symbolize_names: true)

      case data[:type]
      when "trade"
        @aggregator.process_trades(data[:data] || [])
      when "ping"
        @ws&.send(JSON.generate({ type: "pong" }))
      end
    rescue JSON::ParserError => e
      Rails.logger.error("[PriceStreamManager] Invalid JSON: #{e.message}")
    end

    # --- REST Polling Fallback ---

    def run_rest_polling_loop
      set_status("polling")
      client = FinnhubClient.new

      while @running && !market_open?
        symbols = WatchlistItem.all_active_symbols.first(MAX_SLOTS)
        symbols.each do |symbol|
          break unless @running

          begin
            quote = client.quote(symbol)
            broadcast_rest_quote(symbol, quote)
          rescue BaseClient::RateLimitExceeded
            Rails.logger.warn("[PriceStreamManager] REST polling rate limited, pausing")
            break
          rescue BaseClient::ApiError => e
            Rails.logger.error("[PriceStreamManager] REST poll error for #{symbol}: #{e.message}")
          end
        end

        sleep REST_POLL_INTERVAL
      end
    end

    def broadcast_rest_quote(symbol, quote)
      return unless quote.is_a?(Hash)

      payload = {
        symbol: symbol,
        price: quote[:c],
        change: quote[:d],
        change_percent: quote[:dp],
        high: quote[:h],
        low: quote[:l],
        volume: 0,
        vwap: nil,
        timestamp: Time.current.iso8601,
        source: "rest"
      }

      PricesChannel.broadcast_price(symbol, payload)
    end

    # --- WebSocket Helpers ---

    def send_subscribe(symbol)
      return unless @ws

      @ws.send(JSON.generate({ type: "subscribe", symbol: symbol }))
      Rails.logger.debug("[PriceStreamManager] Subscribed to #{symbol}")
    end

    def send_unsubscribe(symbol)
      return unless @ws

      @ws.send(JSON.generate({ type: "unsubscribe", symbol: symbol }))
      Rails.logger.debug("[PriceStreamManager] Unsubscribed from #{symbol}")
    end

    # --- Priority Management ---

    def prioritized_symbols
      WatchlistItem.active.by_priority.pluck(:symbol).uniq
    end

    # --- Redis State ---

    def persist_subscriptions
      REDIS_POOL.with do |redis|
        redis.del("stream:subscriptions")
        redis.sadd("stream:subscriptions", @subscriptions.to_a) if @subscriptions.any?
      end
    end

    def set_status(status)
      REDIS_POOL.with { |r| r.set("stream:status", status) }
    end

    def update_heartbeat
      REDIS_POOL.with { |r| r.set("stream:last_heartbeat", Time.current.to_f.to_s) }
    end

    # --- Heartbeat Thread ---

    def start_heartbeat_thread
      Thread.new do
        while @running
          sleep HEARTBEAT_INTERVAL
          break unless @running

          @ws&.ping("heartbeat")

          sleep HEARTBEAT_TIMEOUT
          last = REDIS_POOL.with { |r| r.get("stream:last_heartbeat").to_f }

          if Time.current.to_f - last > (HEARTBEAT_INTERVAL + HEARTBEAT_TIMEOUT)
            Rails.logger.warn("[PriceStreamManager] Heartbeat timeout, triggering reconnect")
            @ws&.close
            break
          end
        end
      rescue StandardError => e
        Rails.logger.error("[PriceStreamManager] Heartbeat thread error: #{e.message}")
      end
    end

    # --- Command Listener Thread ---

    def start_command_listener_thread
      Thread.new do
        REDIS_POOL.with do |redis|
          pubsub = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
          pubsub.subscribe("stream:commands") do |on|
            on.message do |_channel, message|
              break unless @running

              handle_command(message)
            end
          end
        rescue StandardError => e
          Rails.logger.error("[PriceStreamManager] Command listener error: #{e.message}")
        end
      end
    end

    def handle_command(raw)
      cmd = JSON.parse(raw, symbolize_names: true)
      case cmd[:action]
      when "rebalance"
        rebalance_slots!
      when "subscribe"
        subscribe(cmd[:symbol])
      when "unsubscribe"
        unsubscribe(cmd[:symbol])
      end
    rescue JSON::ParserError => e
      Rails.logger.error("[PriceStreamManager] Invalid command: #{e.message}")
    end

    # --- Signal Handling ---

    def setup_signal_handlers
      %w[TERM INT].each do |signal|
        Signal.trap(signal) do
          Rails.logger.info("[PriceStreamManager] Received SIG#{signal}, shutting down")
          stop
        end
      end
    end
  end
end
