# frozen_string_literal: true

puts "Seeding StockPulse..."

# --- Admin User ---
admin = User.find_or_create_by!(username: "admin") do |u|
  u.telegram_chat_id = ENV["TELEGRAM_CHAT_ID"]
  u.email = ENV.fetch("EMAIL_TO", "admin@stockpulse.dev")
  u.whatsapp_number = ENV["WHATSAPP_TO_NUMBER"]
  u.timezone = "US/Eastern"
end
puts "  User: #{admin.username} (id: #{admin.id})"

# --- Watchlist Items ---
watchlist_data = [
  { symbol: "AAPL", company_name: "Apple Inc.", exchange: "NASDAQ", priority: 5 },
  { symbol: "GOOGL", company_name: "Alphabet Inc.", exchange: "NASDAQ", priority: 4 },
  { symbol: "TSLA", company_name: "Tesla Inc.", exchange: "NASDAQ", priority: 4 },
  { symbol: "MSFT", company_name: "Microsoft Corporation", exchange: "NASDAQ", priority: 3 },
  { symbol: "AMZN", company_name: "Amazon.com Inc.", exchange: "NASDAQ", priority: 3 }
]

watchlist_data.each do |data|
  WatchlistItem.find_or_create_by!(user: admin, symbol: data[:symbol]) do |item|
    item.company_name = data[:company_name]
    item.exchange = data[:exchange]
    item.asset_type = "stock"
    item.priority = data[:priority]
  end
end
puts "  WatchlistItems: #{admin.watchlist_items.count}"

# --- Sample Alerts ---
Alert.find_or_create_by!(user: admin, symbol: "AAPL", alert_type: "price_above") do |a|
  a.condition = { target_price: 200.0 }
  a.notification_channels = %w[telegram email]
  a.notes = "AAPL above $200 target"
end

Alert.find_or_create_by!(user: admin, symbol: "AAPL", alert_type: "rsi_overbought") do |a|
  a.condition = { threshold: 70 }
  a.notification_channels = %w[telegram]
  a.notes = "AAPL RSI overbought signal"
end

Alert.find_or_create_by!(user: admin, symbol: "TSLA", alert_type: "percent_change_up") do |a|
  a.condition = { threshold_percent: 5.0, timeframe: "1d" }
  a.notification_channels = %w[telegram]
  a.notes = "TSLA 5% daily move up"
end

Alert.find_or_create_by!(user: admin, symbol: "GOOGL", alert_type: "news_high_impact") do |a|
  a.condition = { min_sentiment_score: 0.7 }
  a.notification_channels = %w[telegram email]
  a.notes = "GOOGL high-impact news"
end
puts "  Alerts: #{admin.alerts.count}"

puts "Seeding complete!"
puts "  Users: #{User.count}"
puts "  WatchlistItems: #{WatchlistItem.count}"
puts "  Alerts: #{Alert.count}"
