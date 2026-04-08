# frozen_string_literal: true

class StockPulseBot
  COMMANDS = {
    "/start" => :cmd_start,
    "/help" => :cmd_help,
    "/watch" => :cmd_watch,
    "/unwatch" => :cmd_unwatch,
    "/watchlist" => :cmd_watchlist,
    "/alert" => :cmd_alert,
    "/alerts" => :cmd_alerts,
    "/remove" => :cmd_remove,
    "/quote" => :cmd_quote,
    "/analysis" => :cmd_analysis,
    "/briefing" => :cmd_briefing,
    "/mute" => :cmd_mute,
    "/unmute" => :cmd_unmute,
    "/status" => :cmd_status
  }.freeze

  def initialize
    @token = ENV.fetch("TELEGRAM_BOT_TOKEN", nil)
    @running = false
  end

  def start
    return unless @token.present?

    @running = true
    SystemLog.log(level: "info", component: "telegram_bot", message: "StockPulseBot starting")
    poll_updates
  end

  def stop
    @running = false
  end

  private

  def poll_updates
    offset = 0
    conn = Faraday.new(url: "https://api.telegram.org") do |f|
      f.request :json
      f.response :json
      f.options.timeout = 35
      f.adapter Faraday.default_adapter
    end

    while @running
      begin
        response = conn.get("/bot#{@token}/getUpdates", { offset: offset, timeout: 30 })
        updates = response.body["result"] || []

        updates.each do |update|
          offset = update["update_id"] + 1
          handle_update(update)
        rescue StandardError => e
          SystemLog.log(level: "error", component: "telegram_bot", message: "Update error: #{e.message}")
        end
      rescue Faraday::TimeoutError
        next
      rescue StandardError => e
        SystemLog.log(level: "error", component: "telegram_bot", message: "Poll error: #{e.message}")
        sleep(5)
      end
    end
  end

  def handle_update(update)
    message = update["message"]
    return unless message&.dig("text")

    chat_id = message["chat"]["id"].to_s
    text = message["text"].strip
    parts = text.split(" ")
    command = parts.first.downcase.split("@").first

    method = COMMANDS[command]
    if method
      send(method, chat_id, parts[1..])
    elsif text.match?(/\A[A-Z]{1,10}\z/i) && !text.start_with?("/")
      cmd_quote(chat_id, [text.upcase])
    end
  end

  def cmd_start(chat_id, _args)
    user = User.find_or_create_by!(telegram_chat_id: chat_id) do |u|
      u.active = true
    end
    reply(chat_id, "Welcome to StockPulse! Your account is set up.\nUse /help to see available commands.")
  end

  def cmd_help(chat_id, _args)
    reply(chat_id, <<~MSG)
      *StockPulse Commands*

      /watch AAPL - Add symbol to watchlist
      /unwatch AAPL - Remove symbol
      /watchlist - View your watchlist
      /quote AAPL - Get current quote
      /alert AAPL above 200 - Price alert
      /alerts - View active alerts
      /remove 5 - Remove alert #5
      /analysis AAPL - AI analysis
      /briefing - Daily briefing
      /mute - Mute notifications
      /unmute - Unmute notifications
      /status - System status
    MSG
  end

  def cmd_watch(chat_id, args)
    user = find_user(chat_id)
    return reply(chat_id, "Use /start first.") unless user

    symbol = args.first&.upcase
    return reply(chat_id, "Usage: /watch AAPL") unless symbol

    Watchlists::Manager.new.add(user: user, symbol: symbol)
    reply(chat_id, "Added #{symbol} to your watchlist.")
  rescue ActiveRecord::RecordInvalid => e
    reply(chat_id, "Error: #{e.record.errors.full_messages.join(', ')}")
  end

  def cmd_unwatch(chat_id, args)
    user = find_user(chat_id)
    return reply(chat_id, "Use /start first.") unless user

    symbol = args.first&.upcase
    return reply(chat_id, "Usage: /unwatch AAPL") unless symbol

    Watchlists::Manager.new.remove(user: user, symbol: symbol)
    reply(chat_id, "Removed #{symbol} from your watchlist.")
  rescue ActiveRecord::RecordNotFound
    reply(chat_id, "#{symbol} not found in your watchlist.")
  end

  def cmd_watchlist(chat_id, _args)
    user = find_user(chat_id)
    return reply(chat_id, "Use /start first.") unless user

    items = user.watchlist_items.active
    return reply(chat_id, "Your watchlist is empty. Use /watch AAPL to add symbols.") if items.empty?

    # Pre-fetch latest snapshot per symbol to avoid N+1 queries
    symbols = items.map(&:symbol)
    latest_snapshots = PriceSnapshot.where(symbol: symbols)
                                    .order(captured_at: :desc)
                                    .select("DISTINCT ON (symbol) symbol, price, change_percent")
                                    .index_by(&:symbol)

    lines = ["*Your Watchlist*", ""]
    items.each do |item|
      snapshot = latest_snapshots[item.symbol]
      if snapshot
        emoji = snapshot.change_percent.to_f.positive? ? "+" : ""
        lines << "#{item.symbol}: $#{'%.2f' % snapshot.price} (#{emoji}#{'%.2f' % snapshot.change_percent}%)"
      else
        lines << "#{item.symbol}: no data yet"
      end
    end
    reply(chat_id, lines.join("\n"))
  end

  def cmd_alert(chat_id, args)
    user = find_user(chat_id)
    return reply(chat_id, "Use /start first.") unless user
    return reply(chat_id, "Usage: /alert AAPL above 200") unless args.size >= 3

    symbol = args[0].upcase
    direction = args[1].downcase

    alert_type, actual_value = case direction
    when "above"
      ["price_above", args[2].to_f]
    when "below"
      ["price_below", args[2].to_f]
    when "rsi"
      return reply(chat_id, "Usage: /alert AAPL rsi above 70") unless args.size >= 4
      type = args[2].downcase == "above" ? "rsi_overbought" : "rsi_oversold"
      [type, args[3].to_f]
    else
      return reply(chat_id, "Unknown direction. Use: above, below, rsi")
    end

    user.alerts.create!(
      symbol: symbol,
      alert_type: alert_type,
      condition: { "value" => actual_value },
      cooldown_minutes: 15
    )
    reply(chat_id, "Alert created: #{symbol} #{alert_type} #{actual_value}")
  rescue ActiveRecord::RecordInvalid => e
    reply(chat_id, "Error: #{e.record.errors.full_messages.join(', ')}")
  end

  def cmd_alerts(chat_id, _args)
    user = find_user(chat_id)
    return reply(chat_id, "Use /start first.") unless user

    alerts = user.alerts.active
    return reply(chat_id, "No active alerts. Use /alert AAPL above 200 to create one.") if alerts.empty?

    lines = ["*Active Alerts*", ""]
    alerts.each do |alert|
      value = alert.condition&.dig("value")
      lines << "##{alert.id} #{alert.symbol} #{alert.alert_type} #{value}"
    end
    reply(chat_id, lines.join("\n"))
  end

  def cmd_remove(chat_id, args)
    user = find_user(chat_id)
    return reply(chat_id, "Use /start first.") unless user

    raw_id = args.first
    return reply(chat_id, "Usage: /remove <alert_id>") unless raw_id.present? && raw_id.match?(/\A\d+\z/)

    alert_id = raw_id.to_i
    alert = user.alerts.find(alert_id)
    alert.destroy!
    reply(chat_id, "Alert ##{alert_id} removed.")
  rescue ActiveRecord::RecordNotFound
    reply(chat_id, "Alert not found.")
  end

  def cmd_quote(chat_id, args)
    symbol = args.first&.upcase
    return reply(chat_id, "Usage: /quote AAPL") unless symbol

    quote = FinnhubClient.new.quote(symbol)
    reply(chat_id, <<~MSG)
      *#{symbol}*
      Price: $#{'%.2f' % quote['c']}
      Change: #{'%.2f' % quote['d']} (#{'%.2f' % quote['dp']}%)
      High: $#{'%.2f' % quote['h']}
      Low: $#{'%.2f' % quote['l']}
      Open: $#{'%.2f' % quote['o']}
      Prev Close: $#{'%.2f' % quote['pc']}
    MSG
  rescue StandardError => e
    reply(chat_id, "Error fetching quote: #{e.message}")
  end

  def cmd_analysis(chat_id, args)
    symbol = args.first&.upcase
    return reply(chat_id, "Usage: /analysis AAPL") unless symbol

    quote = FinnhubClient.new.quote(symbol)
    analysis = AiServiceClient.new.analyze(
      symbol: symbol,
      price_data: quote,
      technical_data: nil,
      news_data: nil
    )

    reply(chat_id, <<~MSG)
      *AI Analysis: #{symbol}*

      #{analysis['summary']}

      Sentiment: #{analysis['sentiment']}
      Confidence: #{analysis['confidence']}%
      Recommendation: #{analysis['recommendation']}

      _This is not financial advice._
    MSG
  rescue StandardError => e
    reply(chat_id, "Analysis unavailable: #{e.message}")
  end

  def cmd_briefing(chat_id, _args)
    user = find_user(chat_id)
    return reply(chat_id, "Use /start first.") unless user

    MorningBriefingJob.perform_later
    reply(chat_id, "Generating your briefing... You'll receive it shortly.")
  end

  def cmd_mute(chat_id, _args)
    user = find_user(chat_id)
    return reply(chat_id, "Use /start first.") unless user

    user.update!(notifications_muted: true)
    reply(chat_id, "Notifications muted.")
  end

  def cmd_unmute(chat_id, _args)
    user = find_user(chat_id)
    return reply(chat_id, "Use /start first.") unless user

    user.update!(notifications_muted: false)
    reply(chat_id, "Notifications unmuted.")
  end

  def cmd_status(chat_id, _args)
    db = begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      "OK"
    rescue StandardError
      "DOWN"
    end

    redis = begin
      REDIS_POOL.with { |r| r.ping }
      "OK"
    rescue StandardError
      "DOWN"
    end

    reply(chat_id, <<~MSG)
      *System Status*
      Database: #{db}
      Redis: #{redis}
      Watchlist symbols: #{WatchlistItem.active.distinct.count(:symbol)}
      Active alerts: #{Alert.active.count}
    MSG
  end

  def find_user(chat_id)
    User.find_by(telegram_chat_id: chat_id)
  end

  BotUser = Struct.new(:telegram_chat_id, keyword_init: true)

  def reply(chat_id, text)
    Notifications::TelegramSender.new.send_message(
      user: BotUser.new(telegram_chat_id: chat_id),
      message: text
    )
  end
end
