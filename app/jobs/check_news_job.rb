# frozen_string_literal: true

class CheckNewsJob < ApplicationJob
  queue_as :default

  def perform
    symbols = Watchlists::Manager.new.all_watched_symbols
    return if symbols.empty?

    client = MarketAuxClient.new
    news_data = client.news(symbols: symbols, limit: 20)

    symbols.each do |symbol|
      symbol_news = filter_for_symbol(news_data, symbol)
      next if symbol_news.empty?

      evaluate_news_alerts(symbol, symbol_news)
    end
  rescue StandardError => e
    SystemLog.log(level: "error", component: "check_news", message: "Failed: #{e.message}")
  end

  private

  def filter_for_symbol(news_data, symbol)
    articles = news_data["data"] || []
    articles.select do |article|
      entities = article["entities"] || []
      entities.any? { |e| e["symbol"] == symbol }
    end
  end

  def evaluate_news_alerts(symbol, articles)
    news_data = { "data" => articles }
    results = Alerts::Engine.new.evaluate_all(
      symbol: symbol, price_data: {}, news_data: news_data,
      alert_types: Alerts::Engine::NEWS_TYPES
    )

    results.each do |result|
      alert = result[:alert]
      channels = alert.resolved_notification_channels
      AlertHistory.create!(
        alert: alert, user: alert.user, symbol: symbol,
        alert_type: alert.alert_type, message: result[:message],
        data: result[:data], channels_notified: channels,
        triggered_at: Time.current
      )
      SendNotificationJob.perform_later(user_id: alert.user_id, message: result[:message], channels: channels)
    end
  end
end
