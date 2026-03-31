# frozen_string_literal: true

class FinnhubClient < BaseClient
  def initialize
    super(
      api_name: "finnhub",
      base_url: "https://finnhub.io/api/v1",
      rate_limit: ENV.fetch("FINNHUB_RATE_LIMIT_PER_MIN", 60).to_i,
      rate_period: 60
    )
  end

  def quote(symbol)
    cached_get("/quote", { symbol: symbol, token: api_key }, ttl: 30)
  end

  def company_profile(symbol)
    cached_get("/stock/profile2", { symbol: symbol, token: api_key }, ttl: 86_400)
  end

  def basic_financials(symbol)
    cached_get("/stock/metric", { symbol: symbol, metric: "all", token: api_key }, ttl: 3600)
  end

  def search(query)
    cached_get("/search", { q: query, token: api_key }, ttl: 3600)
  end

  def company_news(symbol, from_date: 7.days.ago.strftime("%Y-%m-%d"), to_date: Date.current.strftime("%Y-%m-%d"))
    cached_get("/company-news", { symbol: symbol, from: from_date, to: to_date, token: api_key }, ttl: 900)
  end

  def market_status(exchange: "US")
    cached_get("/stock/market-status", { exchange: exchange, token: api_key }, ttl: 300)
  end

  private

  def api_key
    ENV.fetch("FINNHUB_API_KEY", "")
  end
end
