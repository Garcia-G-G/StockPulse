# frozen_string_literal: true

# Seeds for StockPulse — idempotent, safe to run multiple times.

puts "Seeding StockPulse database..."

# === 1. Default User ===
user = User.find_or_create_by!(telegram_chat_id: ENV.fetch("TELEGRAM_ADMIN_CHAT_ID", "123456789")) do |u|
  u.email = ENV.fetch("ADMIN_EMAIL", "admin@stockpulse.dev")
  u.name = "Admin"
  u.settings = {
    timezone: "US/Eastern",
    language: "es",
    quiet_hours_start: "22:00",
    quiet_hours_end: "08:00",
    notification_channels: %w[telegram email]
  }
end
puts "  User: #{user.name} (#{user.email})"

# === 2. Watchlist Items (top US stocks + crypto) ===
watchlist_data = [
  { symbol: "AAPL",  name: "Apple Inc.",           exchange: "NASDAQ" },
  { symbol: "MSFT",  name: "Microsoft Corp.",       exchange: "NASDAQ" },
  { symbol: "GOOGL", name: "Alphabet Inc.",         exchange: "NASDAQ" },
  { symbol: "AMZN",  name: "Amazon.com Inc.",       exchange: "NASDAQ" },
  { symbol: "NVDA",  name: "NVIDIA Corp.",          exchange: "NASDAQ" },
  { symbol: "TSLA",  name: "Tesla Inc.",            exchange: "NASDAQ" },
  { symbol: "META",  name: "Meta Platforms Inc.",    exchange: "NASDAQ" },
  { symbol: "JPM",   name: "JPMorgan Chase & Co.",  exchange: "NYSE" },
  { symbol: "V",     name: "Visa Inc.",             exchange: "NYSE" },
  { symbol: "BTC",   name: "Bitcoin",               exchange: "CRYPTO" },
]

watchlist_data.each do |data|
  item = WatchlistItem.find_or_create_by!(user: user, symbol: data[:symbol]) do |w|
    w.name = data[:name]
    w.exchange = data[:exchange]
    w.added_at = Time.current
  end
  puts "  Watchlist: #{item.symbol} — #{item.name}"
end

# === 3. Sample Alerts ===
alerts_data = [
  { symbol: "AAPL",  alert_type: "price_above",        condition: { target_price: 250.0 } },
  { symbol: "AAPL",  alert_type: "price_below",         condition: { target_price: 150.0 } },
  { symbol: "TSLA",  alert_type: "price_change_pct",    condition: { percent: 5.0, direction: "any", timeframe: "1d" } },
  { symbol: "NVDA",  alert_type: "rsi_overbought",      condition: { threshold: 70 } },
  { symbol: "NVDA",  alert_type: "rsi_oversold",        condition: { threshold: 30 } },
  { symbol: "MSFT",  alert_type: "volume_spike",        condition: { multiplier: 2.0 } },
  { symbol: "GOOGL", alert_type: "macd_crossover",      condition: { direction: "bullish" } },
  { symbol: "AMZN",  alert_type: "bollinger_breakout",  condition: { band: "upper" } },
  { symbol: "META",  alert_type: "news_sentiment",      condition: { sentiment: "negative", min_score: 0.7 } },
]

alerts_data.each do |data|
  alert = Alert.find_or_create_by!(user: user, symbol: data[:symbol], alert_type: data[:alert_type]) do |a|
    a.condition = data[:condition]
    a.cooldown_minutes = 15
    a.channels = { telegram: true, email: true }
  end
  puts "  Alert: #{alert.symbol} — #{alert.alert_type}"
end

# === 4. System Log Entry ===
SystemLog.find_or_create_by!(component: "seeds", message: "Database seeded successfully") do |log|
  log.level = "info"
end

puts "\nSeeding complete!"
puts "  Users: #{User.count}"
puts "  Watchlist Items: #{WatchlistItem.count}"
puts "  Alerts: #{Alert.count}"
