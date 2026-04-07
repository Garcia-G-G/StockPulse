# frozen_string_literal: true

class AlpacaStreamClient
  HEARTBEAT_INTERVAL = 30
  AUTH_TIMEOUT = 10

  attr_reader :status, :subscribed_symbols

  def initialize(on_trade:, on_bar: nil, on_error: nil, on_status_change: nil)
    @on_trade = on_trade
    @on_bar = on_bar
    @on_error = on_error
    @on_status_change = on_status_change
    @ws = nil
    @status = :disconnected
    @authenticated = false
    @subscribed_symbols = Set.new
    @reconnect_attempts = 0
    @max_reconnect_attempts = 15
  end

  def connect
    return if @status == :connected

    update_status(:connecting)

    @ws = Faye::WebSocket::Client.new(AlpacaConfig::WS_URL)

    @ws.on :open do
      @reconnect_attempts = 0
      authenticate
    end

    @ws.on :message do |event|
      handle_message(event.data)
    end

    @ws.on :close do |event|
      @authenticated = false
      update_status(:disconnected)
      SystemLog.log(level: "warn", component: "alpaca_ws", message: "Connection closed: #{event.code} #{event.reason}")
      schedule_reconnect
    end

    @ws.on :error do |event|
      SystemLog.log(level: "error", component: "alpaca_ws", message: "WebSocket error: #{event.message}")
      @on_error&.call(event.message)
    end
  end

  def disconnect
    @reconnect_attempts = @max_reconnect_attempts # prevent reconnect
    @ws&.close
    @ws = nil
    @authenticated = false
    @subscribed_symbols.clear
    update_status(:disconnected)
  end

  def subscribe(symbols)
    symbols = Array(symbols).map(&:upcase)
    return unless @authenticated && @ws

    new_symbols = symbols - @subscribed_symbols.to_a
    return if new_symbols.empty?

    send_json({ action: "subscribe", trades: new_symbols, bars: new_symbols })
    @subscribed_symbols.merge(new_symbols)
  end

  def unsubscribe(symbols)
    symbols = Array(symbols).map(&:upcase)
    return unless @authenticated && @ws

    removing = symbols & @subscribed_symbols.to_a
    return if removing.empty?

    send_json({ action: "unsubscribe", trades: removing, bars: removing })
    @subscribed_symbols.subtract(removing)
  end

  def connected?
    @status == :connected && @authenticated
  end

  private

  def authenticate
    return unless AlpacaConfig::API_KEY.present? && AlpacaConfig::API_SECRET.present?

    send_json({
      action: "auth",
      key: AlpacaConfig::API_KEY,
      secret: AlpacaConfig::API_SECRET
    })

    # Auth timeout
    EventMachine.add_timer(AUTH_TIMEOUT) do
      unless @authenticated
        SystemLog.log(level: "error", component: "alpaca_ws", message: "Authentication timeout")
        @ws&.close
      end
    end
  end

  def handle_message(raw)
    messages = JSON.parse(raw)
    messages = [messages] unless messages.is_a?(Array)

    messages.each do |msg|
      case msg["T"]
      when "success"
        handle_success(msg)
      when "error"
        handle_error(msg)
      when "subscription"
        handle_subscription_confirm(msg)
      when "t"
        handle_trade(msg)
      when "b"
        handle_bar(msg)
      end
    end
  rescue JSON::ParserError => e
    SystemLog.log(level: "error", component: "alpaca_ws", message: "Parse error: #{e.message}")
  end

  def handle_success(msg)
    case msg["msg"]
    when "connected"
      SystemLog.log(level: "info", component: "alpaca_ws", message: "Connected to Alpaca")
    when "authenticated"
      @authenticated = true
      update_status(:connected)
      SystemLog.log(level: "info", component: "alpaca_ws", message: "Authenticated successfully")
      resubscribe_all
    end
  end

  def handle_error(msg)
    code = msg["code"]
    message = msg["msg"]
    SystemLog.log(level: "error", component: "alpaca_ws", message: "Error #{code}: #{message}")

    case code
    when 402 # auth failed
      @on_error&.call("Authentication failed — check API keys")
    when 404 # auth timeout
      @on_error&.call("Authentication timeout")
    when 405 # symbol limit
      @on_error&.call("Symbol limit exceeded")
    when 406 # connection limit
      @on_error&.call("Connection limit — only 1 allowed on free tier")
    when 407 # slow client
      @on_error&.call("Slow client — not consuming messages fast enough")
    end
  end

  def handle_subscription_confirm(msg)
    SystemLog.log(level: "debug", component: "alpaca_ws",
      message: "Subscribed — trades: #{msg['trades']&.size || 0}, bars: #{msg['bars']&.size || 0}")
  end

  def handle_trade(msg)
    normalized = {
      symbol: msg["S"],
      price: msg["p"].to_f,
      volume: msg["s"].to_i,
      timestamp: Time.parse(msg["t"]).to_i,
      source: "alpaca",
      exchange: msg["x"],
      conditions: msg["c"]
    }
    @on_trade.call(normalized)
  end

  def handle_bar(msg)
    normalized = {
      symbol: msg["S"],
      open: msg["o"].to_f,
      high: msg["h"].to_f,
      low: msg["l"].to_f,
      close: msg["c"].to_f,
      volume: msg["v"].to_i,
      vwap: msg["vw"].to_f,
      trade_count: msg["n"].to_i,
      timestamp: Time.parse(msg["t"]).to_i,
      source: "alpaca"
    }
    @on_bar&.call(normalized)
  end

  def resubscribe_all
    return if @subscribed_symbols.empty?

    symbols = @subscribed_symbols.to_a
    send_json({ action: "subscribe", trades: symbols, bars: symbols })
  end

  def send_json(data)
    return unless @ws

    @ws.send(data.to_json)
  end

  def schedule_reconnect
    return if @reconnect_attempts >= @max_reconnect_attempts

    delay = [2**@reconnect_attempts, 60].min
    @reconnect_attempts += 1
    SystemLog.log(level: "info", component: "alpaca_ws", message: "Reconnecting in #{delay}s (attempt #{@reconnect_attempts})")

    EventMachine.add_timer(delay) { connect }
  end

  def update_status(new_status)
    old_status = @status
    @status = new_status
    @on_status_change&.call(old_status, new_status) if old_status != new_status

    REDIS_POOL.with { |r| r.set("stream:status:alpaca", new_status.to_s) }
  rescue StandardError
    # Redis unavailable — continue without caching status
  end
end
